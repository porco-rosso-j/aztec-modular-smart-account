

contract SchnorrModule {
    use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, Map, PrivateContext, PrivateMutable};
    use dep::authwit::auth_witness::get_auth_witness;
    use dep::aztec::protocol_types::abis::call_context::CallContext;
    use dep::std;

    use dep::notes::public_key_note::PublicKeyNote;
    use dep::helper::{
        get_viewing_pubkeys, get_viewing_pubkeys_and_npkm_hash, extract_signature_64, u8_to_u8_32, 
        };

    use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};

    #[aztec(storage)]
    struct Storage {
        public_keys: Map<AztecAddress, PrivateMutable<PublicKeyNote>>,
    }

    #[aztec(private)]
    fn install(keys: [Field; 500]) {
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);

        // TODO: assert if already initialized
        let mut pub_key_note = PublicKeyNote::new(keys[0], keys[1], npk_m_hash);
        storage.public_keys.at(sender).initialize(&mut pub_key_note, ovpk_m, ivpk_m);
    }

    // #[aztec(private)]
    // fn install(public_key_x: Field, public_key_y:Field) {
    //     let sender = context.msg_sender();
    //     let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);

    //     // TODO: assert if already initialized
    //     let mut pub_key_note = PublicKeyNote::new(public_key_x, public_key_y, npk_m_hash);
    //     storage.public_keys.at(sender).initialize(&mut pub_key_note, ovpk_m, ivpk_m);
    // }


    #[aztec(private)]
    fn uninstall() {
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m) = get_viewing_pubkeys(&mut context, sender);

        // TODO: assert if not initialized
        let mut empty_publickey_note = PublicKeyNote::new(0, 0, 0);
        storage.public_keys.at(sender).replace(&mut empty_publickey_note, ovpk_m, ivpk_m);
    }

    #[aztec(private)]
    fn set_new_public_key(pub_key_x: Field, pub_key_y: Field) {
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);

        // TODO: assert if already initialized

        let mut pub_key_note = PublicKeyNote::new(pub_key_x, pub_key_y, npk_m_hash);
        storage.public_keys.at(sender).replace(&mut pub_key_note, ovpk_m, ivpk_m);  
    }

    #[aztec(private)]
    fn validate(mode: Field, outer_hash: Field) -> bool {
        debug_log_format("mode {0}", [mode]);
        debug_log_format("outer_hash {0}", [outer_hash]);

        // Load public key from storage
        let sender = context.msg_sender();
        debug_log_format("sender {0}", [sender.to_field()]);
        let (ovpk_m, ivpk_m) = get_viewing_pubkeys(&mut context, sender);
        // debug_log_format("ovpk_m {0}", [ovpk_m]);

        let public_key: PublicKeyNote = storage.public_keys.at(sender).get_note(ovpk_m, ivpk_m);
        debug_log_format("public_key.x {0}", [public_key.x]);
        debug_log_format("public_key.y {0}", [public_key.y]);
        // Load auth witness
        let witness: [Field; 500] = get_auth_witness(outer_hash);
        debug_log_format("witness[0] {0}", [witness[0]]);
        let signature: [u8;64] = extract_signature_64(witness, mode);
        
        std::schnorr::verify_signature_slice(public_key.x, public_key.y, signature, outer_hash.to_be_bytes(32))
    }

    unconstrained fn is_installed(account: AztecAddress) -> pub bool {
        storage.public_keys.at(account).is_initialized()
    }

    unconstrained fn view_public_keys(account: AztecAddress) -> pub (Field, Field) {
        let note = storage.public_keys.at(account).view_note();
        (note.x, note.y)
    }
}

