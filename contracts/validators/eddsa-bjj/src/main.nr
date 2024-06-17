mod eddsa_public_key_note;

// Account contract that uses EDDSA signatures for authentication on the same curve as Ethereum.
// The signing key is stored in an immutable private note and should be different from the signing key.
contract EddsaBjjAccount {
    use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, PrivateContext, PrivateImmutable};

    use dep::aztec::protocol_types::abis::call_context::CallContext;
    use dep::std;

    use dep::authwit::{
        entrypoint::{app::AppPayload, fee::FeePayload}, account::AccountActions,
        auth_witness::get_auth_witness
    };

    use crate::eddsa_public_key_note::EddsaPublicKeyNote;

    #[aztec(storage)]
    struct Storage {
        public_key: PrivateImmutable<EddsaPublicKeyNote>,
    }

    global ACCOUNT_ACTIONS_STORAGE_SLOT = 2;

    // Creates a new account out of an ECDSA public key to use for signature verification
    #[aztec(private)]
    #[aztec(initializer)]
    fn constructor(signing_pub_key_x: Field, signing_pub_key_y: Field) {
        let this = context.this_address();
        let header = context.get_header();

        let this_npk_m_hash = header.get_npk_m_hash(&mut context, this);
        let this_ovpk_m = header.get_ovpk_m(&mut context, context.this_address());
        let this_ivpk_m = header.get_ivpk_m(&mut context, context.this_address());

        let mut pub_key_note = EddsaPublicKeyNote::new(signing_pub_key_x, signing_pub_key_y, this_npk_m_hash);
        storage.public_key.initialize(&mut pub_key_note, this_ovpk_m, this_ivpk_m);
    }

    // Note: If you globally change the entrypoint signature don't forget to update default_entrypoint.ts
    #[aztec(private)]
    fn entrypoint(app_payload: AppPayload, fee_payload: FeePayload) {
        let actions = AccountActions::init(&mut context, ACCOUNT_ACTIONS_STORAGE_SLOT, is_valid_impl);
        actions.entrypoint(app_payload, fee_payload);
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

    #[contract_library_method]
    fn is_valid_impl(context: &mut PrivateContext, outer_hash: Field) -> bool {
        // Load public key from storage
        let storage = Storage::init(context);
        let public_key = storage.public_key.get_note();

        // Load auth witness
        let witness: [Field; 3] = get_auth_witness(outer_hash);
        let signature_s = witness[0];
        let signature_r8_x = witness[1];
        let signature_r8_y = witness[2];

        // TODO: make sure that outer_hash == msg?
        let verification = std::eddsa::eddsa_poseidon_verify(
            public_key.x, 
            public_key.y, 
            signature_s, 
            signature_r8_x, 
            signature_r8_y, 
            outer_hash
        );

        assert(verification, "Verification Failed");

        true
    }
}
