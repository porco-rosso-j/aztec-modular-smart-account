mod multisig_note;

global MAX_WITNESS_LEN: Field = 500;

contract MultisigSchnorrModule {
    use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, Map, PrivateContext, PrivateMutable};
    use dep::authwit::auth_witness::get_auth_witness;
    use dep::aztec::protocol_types::abis::call_context::CallContext;
    use dep::std;

    use dep::notes::public_key_note::PublicKeyNote;
    use dep::helper::{
        get_viewing_pubkeys, get_viewing_pubkeys_and_npkm_hash, extract_signature_64, u8_to_u8_32, 
        };

    use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};
    use crate::multisig_note::{MultiSigNote, MAX_MULTISIG_OWNERS};
    use crate::MAX_WITNESS_LEN;

    #[aztec(storage)]
    struct Storage {
        signer_public_keys : Map<AztecAddress, Map<AztecAddress, PrivateMutable<PublicKeyNote>>>,
        multisig_notes: Map<AztecAddress, PrivateMutable<MultiSigNote>>,
    }

    // index 0: signer count
    // index 1: thresdhold
    // index 2~6: owners
    // index 7~16: owners key
    #[aztec(private)]
    fn install(keys: [Field; 500]) {
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);
        
        // TODO: assert if already initialized

        let signer_count = keys[0];
        debug_log_format("signer_count {0}", [signer_count as Field]);

        let thresdhold = keys[1] as u8;

        assert(signer_count as u8 >= thresdhold, "thresdhold greater than signer_count");

        // initialize multisig notes
        let mut owners: [AztecAddress; MAX_MULTISIG_OWNERS] = [AztecAddress::zero(); MAX_MULTISIG_OWNERS];

        // iterate keys to store all ower & keys
        let mut base_owner_index: u8 = 2;
        let mut key_index: u8 = 7;
        for i in 0..MAX_MULTISIG_OWNERS as u8 {
            if i as u8 < signer_count as u8 {
                owners[i] = AztecAddress::from_field(keys[base_owner_index]);
                debug_log_format("owner i {0}", [owners[i].to_field()]);

                debug_log_format("key_index {0}", [key_index as Field]);
                let mut pub_key_note = PublicKeyNote::new(keys[key_index], keys[key_index + 1], npk_m_hash);
                storage.signer_public_keys.at(sender).at(owners[i]).initialize(&mut pub_key_note, ovpk_m, ivpk_m);

                base_owner_index = base_owner_index + 1;
                key_index = key_index + 2;
            }
        }

        let mut multisig_note = MultiSigNote::new(owners, thresdhold, npk_m_hash);
        storage.multisig_notes.at(sender).initialize(&mut multisig_note, ovpk_m, ivpk_m);
    }


    #[aztec(private)]
    fn uninstall() {
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m) = get_viewing_pubkeys(&mut context, sender);

        // TODO: assert if not initialized

        // get current_multisig note
        let mut multisig_note = storage.multisig_notes.at(sender).get_note(ovpk_m, ivpk_m);

        let mut emptry_publickey_note = PublicKeyNote::new(0, 0, 0);
        for owner in multisig_note.owners {
            if owner != AztecAddress::zero() {
                storage.signer_public_keys.at(sender).at(owner).replace(&mut emptry_publickey_note, ovpk_m, ivpk_m);
            }
        }

        multisig_note = MultiSigNote::empty();
        storage.multisig_notes.at(sender).replace(&mut multisig_note, ovpk_m, ivpk_m);

    }

    // todo: allow for changin multiple owners' keys 
    #[aztec(private)]
    fn set_new_public_key(owner: AztecAddress, pub_key_x: Field, pub_key_y: Field) {
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, sender);

        // TODO: assert if already initialized

        let mut pub_key_note = PublicKeyNote::new(pub_key_x, pub_key_y, npk_m_hash);
        storage.signer_public_keys.at(sender).at(owner).replace(&mut pub_key_note, ovpk_m, ivpk_m); 
    }

    // index 0: mode
    // index 1: signer len
    // index 2~6: owners
    // index 7~: 64 * N signatures
    // todo: when not default: there is address at index 1
    // todo: prevent double-spend
    #[aztec(private)]
    fn validate(mode: Field, outer_hash: Field) -> bool {
        debug_log("validate");

        // Load public key from storage
        let sender = context.msg_sender();
        let (ovpk_m, ivpk_m) = get_viewing_pubkeys(&mut context, sender);
        let multisig_note = storage.multisig_notes.at(sender).get_note(ovpk_m, ivpk_m);
        let owners = multisig_note.owners;

        let mut auth_count: u8 = 0;
        let witness: [Field; MAX_WITNESS_LEN] = get_auth_witness(outer_hash);
        let signer_len = witness[1];
        assert(signer_len as u8 >= multisig_note.threshold, "insufficient signer_len");

        let account_to_owners = storage.signer_public_keys.at(sender);

        for i in 0..MAX_MULTISIG_OWNERS as u32 {
            debug_log_format("i {0}", [i as Field]);

            let mut base_index: u32 = i * 65 + 2;
            debug_log_format("base_index {0}", [base_index as Field]);

            let owner_index = witness[base_index] as u32; 
            debug_log_format("owner_index {0}", [owner_index as Field]);

            if (i < signer_len as u32) & (owner_index < MAX_MULTISIG_OWNERS as u32) & (owners[owner_index] != AztecAddress::zero()) {
                debug_log("getting public_key note");
                debug_log_format("owner i {0}", [owners[owner_index].to_field()]);

                let public_key = account_to_owners.at(owners[owner_index]).get_note(ovpk_m, ivpk_m);
                
                let mut signature: [u8; 64] = [0; 64];
                base_index = base_index + 1;

                for j in 0..64 {
                   let sig_index = base_index + (j as u32); 
                   signature[j] = witness[sig_index] as u8;
                }                

               let result = std::schnorr::verify_signature_slice(
                   public_key.x, 
                   public_key.y, 
                   signature, 
                   outer_hash.to_be_bytes(32)
               );

               if result {
                   auth_count += 1;
                   // TODO: break if count >= treshold
               }
            
            }

        }

        auth_count >= multisig_note.threshold
    }

    unconstrained fn is_installed(account: AztecAddress) -> pub bool {
        storage.multisig_notes.at(account).is_initialized()
    }

    unconstrained fn get_multisig_note(account: AztecAddress) -> pub MultiSigNote {
        storage.multisig_notes.at(account).view_note()
    }

    unconstrained fn get_threshold(account: AztecAddress) -> pub u8 {
        storage.multisig_notes.at(account).view_note().threshold
    }

    unconstrained fn get_owners(account: AztecAddress) -> pub [Field;MAX_MULTISIG_OWNERS] {
        let owners = storage.multisig_notes.at(account).view_note().owners;
        let mut owners_field : [Field; MAX_MULTISIG_OWNERS] = [0; MAX_MULTISIG_OWNERS];
        for i in 0..owners.len() {
            owners_field[i] = owners[i].to_field();
        }
        owners_field
    }

    unconstrained fn view_public_keys(account: AztecAddress, owners: AztecAddress) -> pub [Field;2] {
        let note = storage.signer_public_keys.at(account).at(owners).view_note();
        [note.x, note.y]
    }
}

