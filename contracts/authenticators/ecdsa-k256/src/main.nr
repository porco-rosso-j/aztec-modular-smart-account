use dep::aztec::macros::aztec;

// aztec codegen ./ -o ../../../../test/artifacts

global MAX_WITNESS_LEN: u32 = 500;

#[aztec]
contract EcdsaK256Module {
    use dep::aztec::{
        prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, Map, PrivateContext, PrivateMutable},
        encrypted_logs::encrypted_note_emission::encode_and_encrypt_note_with_keys,
        keys::getters::get_public_keys,
        oracle::debug_log::{debug_log, debug_log_format},
        macros::{storage::storage, functions::{private, initializer, view, noinitcheck}},
    };

    use dep::authwit::auth_witness::get_auth_witness;
    use dep::ecdsa_public_key_note::EcdsaPublicKeyNote;
    use dep::std;

    use dep::parser::{extract_pubkeys_32, concat_u8_32, u8_32_to_field_array, u8_64_to_field_array};
    use crate::{MAX_WITNESS_LEN};

    #[storage]
    struct Storage<Context> {
        public_keys: Map<AztecAddress, PrivateMutable<EcdsaPublicKeyNote, Context>, Context>,
    }

    #[private]
    fn install(keys: [Field; MAX_WITNESS_LEN]) {
                
        debug_log("ecdsa install");
        debug_log_format("keys[0] {0}", [keys[0]]);
        debug_log_format("keys[0] {0}", [keys[1]]);
        let sender = context.msg_sender();
        let this_keys = get_public_keys(sender);

        debug_log_format("keys {}", keys);

        let (pub_key_x, pub_key_y) = extract_pubkeys_32(keys);
        debug_log_format("pub_key_x[0] {0}", [pub_key_x[0] as Field]);
        debug_log_format("pub_key_y[0] {0}", [pub_key_y[0] as Field]);

        // TODO: assert if already initialized
        let mut pub_key_note = EcdsaPublicKeyNote::new(pub_key_x, pub_key_y, this_keys.npk_m.hash());
        storage.public_keys.at(sender).initialize(&mut pub_key_note).emit(
            encode_and_encrypt_note_with_keys(
                &mut context, 
                this_keys.ovpk_m, 
                this_keys.ivpk_m, 
                sender
            )
        );
    }

    #[private]
    fn uninstall() {
        let sender = context.msg_sender();
        let this_keys = get_public_keys(sender);

        // make sure this reverts when not initialized
        let public_key: EcdsaPublicKeyNote = storage.public_keys.at(sender).get_note().note;

        let mut empty_publickey_note = EcdsaPublicKeyNote::new([0; 32], [0; 32], 0);
        storage.public_keys.at(sender).replace(&mut empty_publickey_note).emit(
            encode_and_encrypt_note_with_keys(
                &mut context, 
                this_keys.ovpk_m, 
                this_keys.ivpk_m, 
                sender
            )
        );
    }

    #[private]
    fn set_new_public_key(pub_key_x: [u8; 32], pub_key_y: [u8; 32]) {
        let sender = context.msg_sender();
        let this_keys = get_public_keys(sender);

        let mut pub_key_note = EcdsaPublicKeyNote::new(pub_key_x, pub_key_y,  this_keys.npk_m.hash());
        // TODO: check if storage.public_keys.at(sender) already initialized
        storage.public_keys.at(sender).replace(&mut pub_key_note).emit(
            encode_and_encrypt_note_with_keys(
                &mut context, 
                this_keys.ovpk_m, 
                this_keys.ivpk_m, 
                sender
            )
        );  
    }

    #[private]
    fn validate(outer_hash: Field) -> bool {
        debug_log("[EcdsaK256Module] validate...");

        // Load public key from storage
        let sender = context.msg_sender();
        // debug_log_format("sender: {}", [sender.to_field()]);

        let public_key: EcdsaPublicKeyNote = storage.public_keys.at(sender).get_note().note;
        // debug_log_format("public_key.x: {}", u8_32_to_field_array(public_key.x));
        // debug_log_format("public_key.y: {}", u8_32_to_field_array(public_key.y));

        // Load auth witness
        let witness: [Field; MAX_WITNESS_LEN] = get_auth_witness(outer_hash);
        let mut signature: [u8; 64] = [0; 64];
        for i in 0..64 {
            signature[i] = witness[i + 1] as u8;
        }

        // debug_log_format("signature: {}", u8_64_to_field_array(signature));

        // Verify payload signature using Ethereum's signing scheme
        // Note that noir expects the hash of the message/challenge as input to the ECDSA verification.
        let outer_hash_bytes: [u8; 32] = outer_hash.to_be_bytes();
        let hashed_message: [u8; 32] = std::hash::sha256(outer_hash_bytes);
        // debug_log_format("hashed_message: {}", u8_32_to_field_array(hashed_message));
        
        std::ecdsa_secp256k1::verify_signature(public_key.x, public_key.y, signature, hashed_message)
        // let ret = std::ecdsa_secp256k1::verify_signature(public_key.x, public_key.y, signature, hashed_message);
        // debug_log_format("ret: {}", [ret.to_field()]);
        // ret
        // true
    }

    unconstrained fn is_installed(account: AztecAddress) -> pub bool {
        storage.public_keys.at(account).is_initialized()
    }

    unconstrained fn view_public_keys(account: AztecAddress) -> pub [u8;64] {
        let note = storage.public_keys.at(account).view_note();
        concat_u8_32(note.x, note.y)
    }

}
