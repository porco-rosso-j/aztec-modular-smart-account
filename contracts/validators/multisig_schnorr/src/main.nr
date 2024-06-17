// aztec-builder codegen ./target -o ../../../test/artifacts under `multisig_schnorr`
mod public_key_note;
mod multisig_note;

global MAX_WITNESS_NOTE_LEN: Field = 326; // 1 + (65 * 5)

contract MultisigAccountSchnorr {
    use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, PrivateContext, Map, PrivateMutable};
    use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};
    use dep::aztec::protocol_types::{
        grumpkin_private_key::GrumpkinPrivateKey,
        grumpkin_point::GrumpkinPoint,
        abis::call_context::CallContext
    };
    use dep::std;

    use dep::authwit::{
        entrypoint::{app::AppPayload, fee::FeePayload}, account::AccountActions,
        auth_witness::get_auth_witness
    };

    use crate::public_key_note::PublicKeyNote;
    use crate::multisig_note::{MultiSigNote, MAX_MULTISIG_OWNERS, MULTISIG_NOTE_LEN};
    use crate::MAX_WITNESS_NOTE_LEN;

    #[aztec(storage)]
    struct Storage {
        // TODO: this Map<AztecAddress, PrivateImmutable<...>> links nullifier to address
        // https://docs.aztec.network/reference/smart_contract_reference/storage/private_state#initialize
        signing_pubkeys: Map<AztecAddress, PrivateMutable<PublicKeyNote>>,
        multisig_note: PrivateMutable<MultiSigNote>,
    }

    global ACCOUNT_ACTIONS_STORAGE_SLOT = 4;

    // Creates a new account out of an ECDSA public key to use for signature verification
    #[aztec(private)]
    #[aztec(initializer)]
    fn constructor(
        owners: [AztecAddress; MAX_MULTISIG_OWNERS], 
        signing_pubkeys: [GrumpkinPoint; MAX_MULTISIG_OWNERS], 
        threshold: u8,
        iv_secret_key: GrumpkinPrivateKey,
        ov_secret_key: GrumpkinPrivateKey
    ) {
        let header = context.get_header();
        let this = context.this_address();
    
        let this_npk_m_hash = header.get_npk_m_hash(&mut context, this);
        let this_ovpk_m = header.get_ovpk_m(&mut context, this);
        let this_ivpk_m = header.get_ivpk_m(&mut context, this);

        assert(ov_secret_key.derive_public_key().eq(this_ovpk_m), "invalid ovsk");
        assert(iv_secret_key.derive_public_key().eq(this_ivpk_m), "invalid ivsk");

        let mut multisig_note = MultiSigNote::new(owners, threshold, 0, this_npk_m_hash);
        storage.multisig_note.initialize(&mut multisig_note, this_ovpk_m, this_ivpk_m);

        // initialize signing_pubkeys and viewing_pubkeys
        for i in 0..MAX_MULTISIG_OWNERS as u32 {
            if (owners[i] != AztecAddress::zero()) & (signing_pubkeys[i] != GrumpkinPoint::zero()) {
               let npk_m_hash = header.get_npk_m_hash(&mut context, owners[i]);
               let mut signing_public_key = PublicKeyNote::new(signing_pubkeys[i].x, signing_pubkeys[i].y, npk_m_hash);
               storage.signing_pubkeys.at(owners[i]).initialize(&mut signing_public_key, this_ovpk_m, this_ivpk_m); 
            }
        }
    }


    // Note: If you globally change the entrypoint signature don't forget to update default_entrypoint.ts
    #[aztec(private)]
    fn entrypoint(app_payload: AppPayload, fee_payload: FeePayload) {
        let actions = AccountActions::init(&mut context, ACCOUNT_ACTIONS_STORAGE_SLOT, is_valid_impl);
        actions.entrypoint(app_payload, fee_payload);
        debug_log("auth done");

        // increment nonce
        context.call_private_function(
            context.this_address(),
            FunctionSelector::from_signature("increment_nonce()"), 
            []
        );  

        debug_log("nonce incremented");
    }

    #[aztec(private)]
    #[aztec(noinitcheck)]
    fn spend_private_authwit(inner_hash: Field) -> Field {
        let actions = AccountActions::init(&mut context, ACCOUNT_ACTIONS_STORAGE_SLOT, is_valid_impl);
        actions.spend_private_authwit(inner_hash)
    }

    #[aztec(public)]
    fn spend_public_authwit(inner_hash: Field) -> Field {
        let actions = AccountActions::init(&mut context, ACCOUNT_ACTIONS_STORAGE_SLOT, is_valid_impl);
        actions.spend_public_authwit(inner_hash)
    }

    #[aztec(private)]
    #[aztec(internal)]
    fn cancel_authwit(outer_hash: Field) {
        context.push_new_nullifier(outer_hash, 0);
    }

    #[aztec(public)]
    #[aztec(internal)]
    fn approve_public_authwit(outer_hash: Field) {
        let actions = AccountActions::init(&mut context, ACCOUNT_ACTIONS_STORAGE_SLOT, is_valid_impl);
        actions.approve_public_authwit(outer_hash)
    }

    // Witness Structure
    // index 0: signer len
    // index 1: owner index 1
    // index 2-66: signature 1
    // index 67: owner index 2
    // index 68-130: signature 2
    // .... till MAX_MULTISIG_OWNERS

    // TODO: explore option to auto-recover pubkey from sig and msg
    // https://docs.rs/ecdsa/latest/src/ecdsa/recovery.rs.html#281
    #[contract_library_method]
    fn is_valid_impl(context: &mut PrivateContext, outer_hash: Field) -> bool {
 
        let storage = Storage::init(context);
        let header = context.get_header();
        let ovpk_m = header.get_ovpk_m(context, context.this_address());
        let ivpk_m = header.get_ivpk_m(context, context.this_address());
        let multisig = storage.multisig_note.get_note(ovpk_m, ivpk_m);
        let owners = multisig.owners;
       
        let mut auth_count: u8 = 0;
        let witness: [Field; MAX_WITNESS_NOTE_LEN] = get_auth_witness(outer_hash);
        let signer_len = witness[0];
        debug_log_format("signer_len {0}", [signer_len as Field]);
        assert(signer_len as u8 >= multisig.threshold, "insufficient signer_len");

        // onwer index should be put into right before each 64-length signature in withness
        for i in 0..MAX_MULTISIG_OWNERS as u32 {
            debug_log_format("i {0}", [i as Field]);

            let mut base_index: u32 = i * 65 + 1;
            debug_log_format("base_index {0}", [base_index as Field]);

            let owner_index = witness[base_index] as u32; 
            debug_log_format("owner_index {0}", [owner_index as Field]);

            if (i < signer_len as u32) & (owner_index < MAX_MULTISIG_OWNERS as u32) & (owners[owner_index] != AztecAddress::zero()) {
                debug_log("getting public_key note");
                let public_key = storage.signing_pubkeys.at(owners[owner_index]).get_note(ovpk_m, ivpk_m);
                
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

               debug_log_format("result: {0}", [result as Field]);

               if result {
                   auth_count += 1;
                   // TODO: break if count >= treshold
               }
            
            }
        }

        debug_log_format("multisig.threshold {0}", [multisig.threshold as Field]);
        let ret: bool = auth_count >= multisig.threshold;
        debug_log_format("return {0}", [ret as Field]);

        auth_count >= multisig.threshold
    }

    #[aztec(private)]
    fn update_owners(
        new_owners: [AztecAddress; MAX_MULTISIG_OWNERS], 
        new_threshold: u8
    ) {
        let header = context.get_header();
        let ovpk_m = header.get_ovpk_m(&mut context, context.this_address());
        let ivpk_m = header.get_ivpk_m(&mut context, context.this_address());
        
        let note = storage.multisig_note.get_note(ovpk_m, ivpk_m);
        assert(new_threshold <= new_owners.len() as u8, "THRESHOLD_GREATOR_THAN_OWNERS_LEN");
        
        let mut multisig_note = MultiSigNote::new(
            new_owners, 
            new_threshold, 
            note.multisig_account_nonce + 1,
            note.npk_m_hash
        );

        storage.multisig_note.replace(&mut multisig_note, ivpk_m, ovpk_m);

        // TODO: replace public key notes accordingly
    }

    #[aztec(private)]
    #[aztec(internal)]
    fn increment_nonce() {
        let header = context.get_header();
        let ovpk_m = header.get_ovpk_m(&mut context, context.this_address());
        let ivpk_m = header.get_ivpk_m(&mut context, context.this_address());

        let mut note = storage.multisig_note.get_note(ovpk_m, ivpk_m);

        // TODO: entrypoint ints should pass incremental nonce to app payload
        // assert(app_payload.nonce == note.multisig_account_nonce as Field + 1, "Nonce not an increment");
        
        note.multisig_account_nonce = note.multisig_account_nonce + 1;
        storage.multisig_note.replace(&mut note, ivpk_m, ovpk_m);
    }

    unconstrained fn get_owners() -> pub [AztecAddress; MAX_MULTISIG_OWNERS] {
        storage.multisig_note.view_note().owners
    }

    unconstrained fn get_threshold() -> pub u8 {
        storage.multisig_note.view_note().threshold
    }

    unconstrained fn get_nonce() -> pub u32 {
        storage.multisig_note.view_note().multisig_account_nonce
    }

    unconstrained fn get_pubkeys_by_owner(owner: AztecAddress) -> pub PublicKeyNote {
        storage.signing_pubkeys.at(owner).view_note()
    }
}
