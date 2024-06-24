use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteInterface, NoteGetterOptions, PrivateContext};
use dep::aztec::{
    note::utils::compute_note_hash_for_consumption,
    keys::getters::{get_nsk_app, fetch_and_constrain_keys},
    protocol_types::{
        constants::GENERATOR_INDEX__NOTE_NULLIFIER, 
        grumpkin_private_key::GrumpkinPrivateKey, 
        grumpkin_point::GrumpkinPoint, 
        hash::poseidon2_hash,
    },
};

global MAX_MULTISIG_OWNERS: Field = 5;
global MULTISIG_NOTE_LEN: Field = 7;
global MULTISIG_NOTE_BYTES_LEN: Field = 7 * 32 + 64;

// TODO: now sure if ov_secret_key and iv_secret_key are necessary here
// or it also needs to store nullifier and tagging key.
// if seed is controlled by every body
#[aztec(note)]
struct MultiSigNote {
    owners: [AztecAddress; MAX_MULTISIG_OWNERS],
    threshold: u8,  // threshold for the multi-sig
    npk_m_hash: Field, // npk_m_hash to get the secret key to compute the nullifier
}

impl MultiSigNote {
    pub fn new(
       owners: [AztecAddress; MAX_MULTISIG_OWNERS],
       threshold: u8,  // threshold for the multi-sig
       npk_m_hash: Field, // npk_m_hash to get the secret key to compute the nullifier
    ) -> Self {
        MultiSigNote { 
            owners, 
            threshold, 
            npk_m_hash, 
            header: NoteHeader::empty() 
        }
    }

    pub fn empty() -> Self {
        let owners: [AztecAddress; MAX_MULTISIG_OWNERS] = [AztecAddress::zero(); MAX_MULTISIG_OWNERS];

        MultiSigNote {
            owners,
            threshold: 0,
            npk_m_hash: 0,
            header: NoteHeader::empty() 
        }

    }
}

impl NoteInterface<MULTISIG_NOTE_LEN, MULTISIG_NOTE_BYTES_LEN> for MultiSigNote {

    fn serialize_content(self) -> [Field; MULTISIG_NOTE_LEN] {
        let mut serialized_note: [Field; MULTISIG_NOTE_LEN] = [0; MULTISIG_NOTE_LEN];
        for i in 0..MAX_MULTISIG_OWNERS as u8 {
            if self.owners[i] != AztecAddress::zero() {
               serialized_note[i] = self.owners[i].to_field();
            } else {
               serialized_note[i] = 0;
            }
        }

        serialized_note[MAX_MULTISIG_OWNERS] = self.threshold as Field;
        serialized_note[MAX_MULTISIG_OWNERS + 1] = self.npk_m_hash;
        serialized_note
    }

    // Cannot use the automatic deserialization for the aforementioned reasons
    fn deserialize_content(serialized_note: [Field; MULTISIG_NOTE_LEN]) -> Self {
        let mut owners: [AztecAddress; MAX_MULTISIG_OWNERS] = [AztecAddress::zero(); MAX_MULTISIG_OWNERS];
        for i in 0..MAX_MULTISIG_OWNERS as u8 {
            if serialized_note[i] != 0 {
                owners[i] = AztecAddress::from_field(serialized_note[i]);
            } else {
                owners[i] = AztecAddress::zero();
            }
        }

        let threshold = serialized_note[MAX_MULTISIG_OWNERS] as u8;
        let npk_m_hash = serialized_note[MAX_MULTISIG_OWNERS + 1];

        MultiSigNote { 
            owners, 
            threshold, 
            npk_m_hash, 
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

    // TODO: address an error: "No matching impl found for `[Field; 12]: LensForEncryptedLog<12, _>`"
    // https://github.com/AztecProtocol/aztec-packages/blob/024e85f746f7e67b415ff1e9492a4fecfed74920/noir-projects/aztec-nr/aztec/src/oracle/logs_traits.nr#L12
    // this trait should support length > 6
    // Broadcasts the note as an encrypted log on L1.
    fn broadcast(self, context: &mut PrivateContext, slot: Field, ovpk_m: GrumpkinPoint, ivpk_m: GrumpkinPoint) {
        
        for owner_address in self.owners {
            if owner_address != AztecAddress::zero() {
              // NOTE: not sure why this compiles while `fetch_and_constrain_keys` is not with pub
              let pubkeys = fetch_and_constrain_keys(owner_address);
              context.encrypt_and_emit_note(
                (*context).this_address(),
                 slot,
                 Self::get_note_type_id(),
                 pubkeys.ovpk_m,
                 pubkeys.ivpk_m,
                 self,
              );
            }
        }
    }
}
