use dep::aztec::prelude::{AztecAddress, NoteHeader, NoteInterface, NullifiableNote, PrivateContext};
use dep::aztec::protocol_types::abis::function_selector::FunctionSelector;
use dep::aztec::{
    note::utils::compute_note_hash_for_nullify,
    keys::getters::get_nsk_app,
    protocol_types::{
        constants::GENERATOR_INDEX__NOTE_NULLIFIER, 
        hash::poseidon2_hash_with_separator,
    },
    macros::notes::note_custom_interface, generators::Ga1 as Gx_1, generators::Ga2 as Gx_2,
    generators::Ga3 as Gy_1, generators::Ga4 as Gy_2, generators::Ga5 as Gnpk_m_hash, generators::G_slot,
    oracle::debug_log::{debug_log, debug_log_format},
};

use std::hash::from_field_unsafe;

global AUTHENTICATOR_NOTE_LEN: u32 = 3;
global INSTALL_KEYS_LEN = 500;

// #[aztec(note)]
#[note_custom_interface]
struct AuthenticatorNote {
    address: AztecAddress, // necessary? mb yes if note doesn't tie map key which is az addr
    enabled: bool,
    npk_m_hash: Field, // npk_m_hash to get the secret key to compute the nullifier
}

impl AuthenticatorNote {
    pub fn new(
       address: AztecAddress,
       enabled: bool,
       npk_m_hash: Field, 
    ) -> Self {
        AuthenticatorNote { 
            address, 
            enabled, 
            npk_m_hash,
            header: NoteHeader::empty()
        }
    }

    pub fn empty() -> Self {
        AuthenticatorNote { 
            address: AztecAddress::zero(), 
            enabled: false, 
            npk_m_hash: 0,
            header: NoteHeader::empty()
        }
    }

    pub fn validate(
        self: Self,
        context: &mut PrivateContext,
        outer_hash: Field
    ) -> bool {
         debug_log("[AuthenticatorNote] validate...");

        let mut ret = false;
        // debug_log_format("authenticator: {}", [self.address.to_field()]);
        // debug_log_format("outer_hash: {}", [outer_hash]);
        if self.address != AztecAddress::zero() {
            // debug_log("self.address != AztecAddress::zero()");
            let call = comptime {
               FunctionSelector::from_signature("validate(Field)")
            };

            ret = context.call_private_function(
               self.address,
               call,
               [outer_hash],
            ).unpack_into();
        } 

        // debug_log_format("ret: {}", [ret.to_field()]);

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
            FunctionSelector::from_signature("install([Field;500])"),
            keys
        );
    }

    // uninstall
    pub fn uninstall(
        self: Self,
        context: &mut PrivateContext
    ) {
        context.call_private_function(
            self.address,
            FunctionSelector::from_signature("uninstall()"),
            [],
        );
    }
}

impl NoteInterface<AUTHENTICATOR_NOTE_LEN> for AuthenticatorNote {

    fn serialize_content(self) -> [Field; AUTHENTICATOR_NOTE_LEN] {
        [self.address.to_field(), self.enabled as Field, self.npk_m_hash]
    }

    // Cannot use the automatic deserialization for the aforementioned reasons
    fn deserialize_content(serialized_note: [Field; AUTHENTICATOR_NOTE_LEN]) -> Self {
        AuthenticatorNote { 
            address: AztecAddress::from_field(serialized_note[0]), 
            enabled: serialized_note[1] as bool, 
            npk_m_hash: serialized_note[2],
            header: NoteHeader::empty()
        }
    }


   fn to_be_bytes(self, storage_slot: Field) -> [u8; AUTHENTICATOR_NOTE_LEN * 32 + 64] {
        let serialized_note = self.serialize_content();

        let mut buffer: [u8; AUTHENTICATOR_NOTE_LEN * 32 + 64] = [0; AUTHENTICATOR_NOTE_LEN * 32 + 64];

        let storage_slot_bytes: [u8; 32] = storage_slot.to_be_bytes();
        let note_type_id_bytes: [u8; 32] = AuthenticatorNote::get_note_type_id().to_be_bytes();

        for i in 0..32 {
            buffer[i] = storage_slot_bytes[i];
            buffer[32 + i] = note_type_id_bytes[i];
        }

        for i in 0..serialized_note.len() {
            let bytes: [u8; 32] = serialized_note[i].to_be_bytes();
            for j in 0..32 {
                buffer[64 + i * 32 + j] = bytes[j];
            }
        }
        buffer
    }

    fn get_note_type_id() -> Field {
        comptime
        {
            let bytes = "AuthenticatorNote".as_bytes();
            let hash = aztec::protocol_types::hash::poseidon2_hash_bytes(bytes);
            let hash_bytes = hash.to_be_bytes::<4>();
            aztec::protocol_types::utils::field::field_from_bytes(hash_bytes, true)
        }
    }

    fn get_header(self) -> NoteHeader {
        self.header
    }

    fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    fn compute_note_hash(self) -> Field {
        let serialized = self.serialize_content();
        std::embedded_curve_ops::multi_scalar_mul(
            [Gx_1, Gx_2, Gy_1, Gy_2, Gnpk_m_hash, G_slot],
            [
            from_field_unsafe(serialized[0]),
            from_field_unsafe(serialized[1]),
            from_field_unsafe(serialized[2]),
            from_field_unsafe(0),
            from_field_unsafe(0),
            // from_field_unsafe(serialized[3]), // TODO: does this work?
            // from_field_unsafe(serialized[4]),
            from_field_unsafe(self.get_header().storage_slot)
        ]
        ).x
    }
}


impl NullifiableNote for AuthenticatorNote {

    fn compute_nullifier(self, context: &mut PrivateContext, note_hash_for_nullify: Field) -> Field {
        let secret = context.request_nsk_app(self.npk_m_hash);
        poseidon2_hash_with_separator(
            [
            note_hash_for_nullify,
            secret
        ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }

    unconstrained fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_nullify(self);
        let secret = get_nsk_app(self.npk_m_hash);
        poseidon2_hash_with_separator(
            [
            note_hash_for_nullify,
            secret
        ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }
}