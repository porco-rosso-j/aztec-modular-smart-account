use dep::aztec::prelude::{AztecAddress, NoteHeader, NoteInterface, PrivateContext};
use dep::aztec::protocol_types::abis::function_selector::FunctionSelector;
use dep::aztec::{
    note::utils::compute_note_hash_for_consumption,
    keys::getters::get_nsk_app,
    protocol_types::{
        constants::GENERATOR_INDEX__NOTE_NULLIFIER, 
        grumpkin_private_key::GrumpkinPrivateKey, 
        grumpkin_point::GrumpkinPoint, 
        hash::poseidon2_hash,
    },
};
use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};

global VALIDATOR_NOTE_LEN: Field = 3;
global VALIDATOR_NOTE_BYTES_LEN: Field = 4 * 32 + 64;
global VALIDATE_SELECTOR: Field = 0xdd0526f3;
global INSTALL_SELECTOR: Field = 0x7b42afcc;
global UNINSTALL_SELECTOR: Field = 0x0d638f30;
// global MAX_INSTALL_KEYS_LEN = 10;
global INSTALL_KEYS_LEN = 500;

#[aztec(note)]
struct ValidatorNote {
    address: AztecAddress, // necessary? mb yes if note doesn't tie map key which is az addr
    enabled: bool,
    npk_m_hash: Field, // npk_m_hash to get the secret key to compute the nullifier
}

impl ValidatorNote {


    pub fn new(
       address: AztecAddress,
       enabled: bool,
       npk_m_hash: Field, 
    ) -> Self {
        ValidatorNote { 
            address, 
            enabled, 
            npk_m_hash,
            header: NoteHeader::empty()
        }
    }

    pub fn empty() -> Self {
        ValidatorNote { 
            address: AztecAddress::zero(), 
            enabled: false, 
            npk_m_hash: 0,
            header: NoteHeader::empty()
        }
    }

    pub fn validate(
        self: Self,
        context: &mut PrivateContext,
        mode: Field,
        outer_hash: Field
    ) -> bool {
        let mut ret = false;
        if self.address != AztecAddress::zero() {
            ret = context.call_private_function(
               self.address,
               FunctionSelector::from_field(VALIDATE_SELECTOR),
               [mode, outer_hash],
            ).unpack_into();
        } 

        ret 
    }

    // install
    pub fn install(
        self: Self,
        context: &mut PrivateContext,
        keys: [Field; INSTALL_KEYS_LEN]
    ) {
        context.call_private_function(
            self.address,
            // FunctionSelector::from_field(INSTALL_SELECTOR),
            // FunctionSelector::from_signature("install(Field,Field)"),
            FunctionSelector::from_signature("install([Field;500])"),
            keys
            // keys,
            //
            // [keys[0], keys[1]]
        );
    }

    // uninstall
    pub fn uninstall(
        self: Self,
        context: &mut PrivateContext
    ) {
        context.call_private_function(
            self.address,
            FunctionSelector::from_field(UNINSTALL_SELECTOR),
            [],
        );
    }
}

impl NoteInterface<VALIDATOR_NOTE_LEN, VALIDATOR_NOTE_BYTES_LEN> for ValidatorNote {

    fn serialize_content(self) -> [Field; VALIDATOR_NOTE_LEN] {
        let mut serialized_note: [Field; VALIDATOR_NOTE_LEN] = [0; VALIDATOR_NOTE_LEN];
        serialized_note[0] = self.address.to_field();
        serialized_note[1] = self.enabled as Field;
        serialized_note[2] = self.npk_m_hash;
        serialized_note
    }

    // Cannot use the automatic deserialization for the aforementioned reasons
    fn deserialize_content(serialized_note: [Field; VALIDATOR_NOTE_LEN]) -> Self {
        ValidatorNote { 
            address: AztecAddress::from_field(serialized_note[0]), 
            enabled: serialized_note[1] as bool, 
            npk_m_hash: serialized_note[2],
            header: NoteHeader::empty()
        }
    }

   fn compute_nullifier(self, context: &mut PrivateContext) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_consumption(self);
        let secret = context.request_nsk_app(self.npk_m_hash);
        poseidon2_hash([
            note_hash_for_nullify,
            secret,
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        ])
    }

    fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_consumption(self);
        let secret = get_nsk_app(self.npk_m_hash);
        poseidon2_hash([
            note_hash_for_nullify,
            secret,
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        ])
    }

    // Broadcasts the note as an encrypted log on L1.
    fn broadcast(self, context: &mut PrivateContext, slot: Field, ovpk_m: GrumpkinPoint, ivpk_m: GrumpkinPoint) {

        context.encrypt_and_emit_note(
            (*context).this_address(),
            slot,
            Self::get_note_type_id(),
            ovpk_m,
            ivpk_m,
            self,
        )
    }
}
