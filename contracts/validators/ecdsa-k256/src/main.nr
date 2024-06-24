
contract EcdsaK256Module {
    use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, Map, PrivateContext, PrivateMutable};
    use dep::authwit::auth_witness::get_auth_witness;
    use dep::aztec::protocol_types::abis::call_context::CallContext;
    use dep::std;
    use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};

    use dep::notes::ecdsa_public_key_note::EcdsaPublicKeyNote;
    use dep::helper::{
        get_viewing_pubkeys, get_viewing_pubkeys_and_npkm_hash, extract_signature_64, extract_pubkeys_32, 
        };

    #[aztec(storage)]
    struct Storage {
        public_keys: Map<AztecAddress, PrivateMutable<EcdsaPublicKeyNote>>,
    }

    #[aztec(private)]
    fn install(keys: [Field; 500]) {
                
        debug_log("ecdsa install");
        debug_log_format("keys[0] {0}", [keys[0]]);
        debug_log_format("keys[0] {0}", [keys[1]]);
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);

        let (pub_key_x, pub_key_y) = extract_pubkeys_32(keys);
        debug_log_format("pub_key_x[0] {0}", [pub_key_x[0] as Field]);
        debug_log_format("pub_key_y[0] {0}", [pub_key_y[0] as Field]);

        // TODO: assert if already initialized
        let mut pub_key_note = EcdsaPublicKeyNote::new(pub_key_x, pub_key_y, npk_m_hash);
        storage.public_keys.at(sender).initialize(&mut pub_key_note, ovpk_m, ivpk_m);
    }

    #[aztec(private)]
    fn uninstall() {
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m) = get_viewing_pubkeys(&mut context, sender);

        // TODO: assert if not initialized
        let mut empty_publickey_note = EcdsaPublicKeyNote::new([0; 32], [0; 32], 0);
        storage.public_keys.at(sender).replace(&mut empty_publickey_note, ovpk_m, ivpk_m);
    }

    #[aztec(private)]
    fn set_new_public_key(pub_key_x: [u8; 32], pub_key_y: [u8; 32]) {
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);

        // TODO: assert if already initialized

        let mut pub_key_note = EcdsaPublicKeyNote::new(pub_key_x, pub_key_y, npk_m_hash);
        storage.public_keys.at(sender).replace(&mut pub_key_note, ovpk_m, ivpk_m);  
    }

    #[aztec(private)]
    fn validate(mode: Field, outer_hash: Field) -> bool {
        // Load public key from storage
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m) = get_viewing_pubkeys(&mut context, sender);

        let public_key: EcdsaPublicKeyNote = storage.public_keys.at(sender).get_note(ovpk_m, ivpk_m);

        // Load auth witness
        let witness: [Field; 500] = get_auth_witness(outer_hash);
        let signature: [u8;64] = extract_signature_64(witness, mode);

        // Verify payload signature using Ethereum's signing scheme
        // Note that noir expects the hash of the message/challenge as input to the ECDSA verification.
        let outer_hash_bytes: [u8; 32] = outer_hash.to_be_bytes(32).as_array();
        let hashed_message: [u8; 32] = std::hash::sha256(outer_hash_bytes);
        
        std::ecdsa_secp256k1::verify_signature(public_key.x, public_key.y, signature, hashed_message)
    }

    unconstrained fn is_installed(account: AztecAddress) -> pub bool {
        storage.public_keys.at(account).is_initialized()
    }

    unconstrained fn view_public_keys(account: AztecAddress) -> pub ([u8;32], [u8;32]) {
        let note = storage.public_keys.at(account).view_note();
        (note.x, note.y)
    }
}




    // #[aztec(private)]
    // fn install(pub_key_x: [u8; 32], pub_key_y: [u8; 32]) {
    //     let sender = context.msg_sender();
    //     let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);

    //     // TODO: assert if already initialized

    //     let mut pub_key_note = EcdsaPublicKeyNote::new(pub_key_x, pub_key_y, npk_m_hash);
    //     storage.public_keys.at(sender).initialize(&mut pub_key_note, ovpk_m, ivpk_m);
    // }
    // #[aztec(private)]
    // fn install(mode: Field, date: [Field;10]) {
    //     let sender = context.msg_sender();
    //     let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);

    //     let mut pub_key_x: [u8; 32] = [0; 32];
    //     let mut pub_key_y: [u8; 32] = [0; 32];

    //     if mode == 0 {
    //         pub_key_x = field_to_u32(data[0]);
    //         pub_key_y = field_to_u32(data[1]);
    //     } else if mode == 1 {
    //         let witness: [Field; 500] = get_auth_witness(date[0]);
    //         (pub_key_x, pub_key_y) = extract_pubkeys_32(witness, mode);
    //     }

    //     // TODO: assert if already initialized

    //     let mut pub_key_note = EcdsaPublicKeyNote::new(pub_key_x, pub_key_y, npk_m_hash);
    //     storage.public_keys.at(sender).initialize(&mut pub_key_note, ovpk_m, ivpk_m);
    // }