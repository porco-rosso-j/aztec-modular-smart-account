use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteInterface, NoteGetterOptions, PrivateContext};

use dep::aztec::{
    note::utils::compute_note_hash_for_consumption,
    keys::getters::get_nsk_app,
    protocol_types::{constants::GENERATOR_INDEX__NOTE_NULLIFIER, grumpkin_point::GrumpkinPoint, hash::poseidon2_hash}
};

global EDDSA_PUBLIC_KEY_NOTE_LEN: Field = 3;
global EDDSA_PUBLIC_KEY_NOTE_BYTES_LEN: Field = 3 * 32 + 64;

// Stores an ECDSA public key composed of two 32-byte elements
// TODO: Do we need to include a nonce, in case we want to read/nullify/recreate with the same pubkey value?
#[aztec(note)]
struct EddsaPublicKeyNote {
    x: Field,
    y: Field,
    // We store the npk_m_hash only to get the secret key to compute the nullifier
    npk_m_hash: Field,
}

impl NoteInterface<EDDSA_PUBLIC_KEY_NOTE_LEN, EDDSA_PUBLIC_KEY_NOTE_BYTES_LEN> for EddsaPublicKeyNote {
    fn serialize_content(self) -> [Field; EDDSA_PUBLIC_KEY_NOTE_LEN] {
        [self.x, self.y, self.npk_m_hash]
    }

    // Cannot use the automatic deserialization for the aforementioned reasons
    fn deserialize_content(serialized_note: [Field; EDDSA_PUBLIC_KEY_NOTE_LEN]) -> EddsaPublicKeyNote {
        EddsaPublicKeyNote { 
            x: serialized_note[0], 
            y: serialized_note[1], 
            npk_m_hash: serialized_note[4], 
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
        );
    }
}

impl EddsaPublicKeyNote {
    pub fn new(x: Field, y: Field, npk_m_hash: Field) -> Self {
        EddsaPublicKeyNote { x, y, npk_m_hash, header: NoteHeader::empty() }
    }
}
