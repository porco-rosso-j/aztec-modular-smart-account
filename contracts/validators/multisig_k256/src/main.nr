mod ecdsa_public_key_note;
mod multisig_note;
mod helper;

global MAX_WITNESS_NOTE_LEN: Field = 325; // 65 * 5

contract MultisigAccountK256 {
    use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, PrivateContext, Map, PrivateMutable};

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

    use crate::ecdsa_public_key_note::EcdsaPublicKeyNote;
    use crate::multisig_note::{MultiSigNote, MAX_MULTISIG_OWNERS, MULTISIG_NOTE_LEN};
    use crate::helper::u8_to_u8_32;
    use crate::MAX_WITNESS_NOTE_LEN;
    

    #[aztec(storage)]
    struct Storage {
        // TODO: this Map<AztecAddress, PrivateImmutable<...>> links nullifier to address
        // https://docs.aztec.network/reference/smart_contract_reference/storage/private_state#initialize
        signing_pubkeys: Map<AztecAddress, PrivateMutable<EcdsaPublicKeyNote>>,
        multisig_note: PrivateMutable<MultiSigNote>,
    }

    global ACCOUNT_ACTIONS_STORAGE_SLOT = 4;

    // Creates a new account out of an ECDSA public key to use for signature verification
    #[aztec(private)]
    #[aztec(initializer)]
    fn constructor(
        owners: [AztecAddress; MAX_MULTISIG_OWNERS], 
        pubkeys: [GrumpkinPoint; MAX_MULTISIG_OWNERS], // TODO: not grumpkin
        owner_ovpks: [GrumpkinPoint; MAX_MULTISIG_OWNERS],
        owner_ivpks: [GrumpkinPoint; MAX_MULTISIG_OWNERS],
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
            let npk_m_hash = header.get_npk_m_hash(&mut context, owners[i]);
            let pubkey_x: [u8;32] = u8_to_u8_32(pubkeys[i].x.to_le_bytes(32));
            let pubkey_y: [u8;32] = u8_to_u8_32(pubkeys[i].y.to_le_bytes(32));
            let mut signing_public_key = EcdsaPublicKeyNote::new(pubkey_x, pubkey_y, npk_m_hash);
            storage.signing_pubkeys.at(owners[i]).initialize(&mut signing_public_key, owner_ovpks[i], owner_ivpks[i]);         
        }
    }

    // Note: If you globally change the entrypoint signature don't forget to update default_entrypoint.ts
    #[aztec(private)]
    fn entrypoint(app_payload: AppPayload, fee_payload: FeePayload) {
        let actions = AccountActions::init(&mut context, ACCOUNT_ACTIONS_STORAGE_SLOT, is_valid_impl);
        actions.entrypoint(app_payload, fee_payload);

        let header = context.get_header();
        let ivpk_m = header.get_ivpk_m(&mut context, context.this_address());
        let ovpk_m = header.get_ivpk_m(&mut context, context.this_address());
        let note = storage.multisig_note.get_note(ovpk_m, ivpk_m);
        // check nonce
        assert(app_payload.nonce == note.multisig_account_nonce as Field + 1, "Nonce not an increment");

        // increment nonce
        context.call_private_function(
            context.this_address(),
            FunctionSelector::from_signature("incremenet_nonce()"), 
            []
        );  
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

    // TODO: explore option to auto-recover pubkey from sig and msg
    // https://docs.rs/ecdsa/latest/src/ecdsa/recovery.rs.html#281
    #[contract_library_method]
    fn is_valid_impl(context: &mut PrivateContext, outer_hash: Field) -> bool {
        // Load public key from storage
        let storage = Storage::init(context);
        let header = context.get_header();
        let ovpk_m = header.get_ovpk_m(context, context.this_address());
        let ivpk_m = header.get_ivpk_m(context, context.this_address());
        let multisig = storage.multisig_note.get_note(ovpk_m, ivpk_m);
        let owners = multisig.owners;
       
        let outer_hash_bytes: [u8; 32] = outer_hash.to_be_bytes(32).as_array();
        let hashed_message: [u8; 32] = std::hash::sha256(outer_hash_bytes);

        let mut auth_count: u8 = 0;
        let witness: [Field; MAX_WITNESS_NOTE_LEN] = get_auth_witness(outer_hash);

        // onwer index should be put into right before each 64-length signature in withness
        for i in 0..MAX_MULTISIG_OWNERS as u32 {
            let mut owner_index = witness[i * 65] as u8;

            if (owner_index < MAX_MULTISIG_OWNERS as u8) & (owners[owner_index] != AztecAddress::zero()) {
               let public_key = storage.signing_pubkeys.at(owners[owner_index]).get_note(ovpk_m, ivpk_m);
               
               let mut signature: [u8; 64] = [0; 64];
               owner_index = owner_index + 1;
               for j in 0..64 {
                   let index = owner_index + j as u8; 
                   signature[j] = witness[owner_index] as u8;
               }

               let result = std::ecdsa_secp256k1::verify_signature(
                   public_key.x, 
                   public_key.y, 
                   signature, 
                   hashed_message
               );

               if result {
                   auth_count += 1;
                   // TODO: break if count >= treshold
               }
            
            }
        }

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
    }

    #[aztec(private)]
    fn incremenet_nonce() {
        let header = context.get_header();
        let ovpk_m = header.get_ovpk_m(&mut context, context.this_address());
        let ivpk_m = header.get_ivpk_m(&mut context, context.this_address());

        let mut note = storage.multisig_note.get_note(ovpk_m, ivpk_m);
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
}
