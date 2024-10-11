use dep::aztec::macros::aztec;
mod authenticator_note;

// aztec codegen ./ -o ../../test/artifacts

global MAX_WITNESS_LEN: u32 = 500;

#[aztec]
contract KernelAccount {
    use dep::aztec::{
        prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, Map, PrivateContext, PrivateMutable, SharedMutable},
        encrypted_logs::encrypted_note_emission::encode_and_encrypt_note_with_keys,
        keys::getters::get_public_keys,
        macros::{storage::storage, functions::{private, initializer, view, noinitcheck}},
        oracle::debug_log::{debug_log, debug_log_format},
    };

    use dep::authwit::{
        entrypoint::{app::AppPayload, fee::FeePayload}, account::AccountActions,
        auth_witness::get_auth_witness,
    }; 

    use dep::value_note::value_note::ValueNote;
    use dep::address_note::address_note::AddressNote;
    
    use crate::authenticator_note::{AuthenticatorNote, INSTALL_KEYS_LEN};
    use crate::{MAX_WITNESS_LEN};
    
    #[storage]
    struct Storage<Context> {
        authenticators: Map<AztecAddress, PrivateMutable<AuthenticatorNote, Context>, Context>,
        nonce: PrivateMutable<ValueNote, Context>,
    }

    #[private]
    #[initializer]
    fn constructor(authenticator: AztecAddress, signing_pubkeys:[Field; INSTALL_KEYS_LEN]) {
        let this = context.this_address();
        let this_keys = get_public_keys(this);

        let mut nonce_note = ValueNote::new(0, this_keys.npk_m.hash());
        storage.nonce.initialize(&mut nonce_note).emit(encode_and_encrypt_note_with_keys(&mut context, this_keys.ovpk_m, this_keys.ivpk_m, this));
        
        let mut authenticator_note = AuthenticatorNote::new(authenticator, true, this_keys.npk_m.hash());
        storage.authenticators.at(authenticator).initialize(&mut authenticator_note).emit(encode_and_encrypt_note_with_keys(&mut context, this_keys.ovpk_m, this_keys.ivpk_m, this));
        authenticator_note.install(&mut context, signing_pubkeys);
    }

    // Note: If you globally change the entrypoint signature don't forget to update default_entrypoint.ts
    #[private]
    fn entrypoint(app_payload: AppPayload, fee_payload: FeePayload, cancellable: bool) {
        // debug_log("entrypoint...");
        dep::aztec::oracle::debug_log::debug_log("entrypoint...");
        let actions = AccountActions::init(&mut context, is_valid_impl);
        actions.entrypoint(app_payload, fee_payload, cancellable);

        // validate and increment nonce
        // context.call_private_function(
        //     context.this_address(),
        //     FunctionSelector::from_signature("_validate_and_update_nonce(Field)"), 
        //     [app_payload.nonce]
        // );  
    }

    #[private]
    #[noinitcheck]
    #[view]
    fn verify_private_authwit(inner_hash: Field) -> Field {
        let actions = AccountActions::init(&mut context, is_valid_impl);
        actions.verify_private_authwit(inner_hash)
    }

    #[contract_library_method]
    fn is_valid_impl(context: &mut PrivateContext, outer_hash: Field) -> bool {
        // debug_log("is_valid_impl...");
         dep::aztec::oracle::debug_log::debug_log("is_valid_impl...");
        // Load public key from storage
        let storage = Storage::init(context);

        // Load auth witness
        let witness: [Field; MAX_WITNESS_LEN] = unsafe { get_auth_witness(outer_hash) };
        debug_log_format("witness[0]: {}", [witness[0]]);
        let authenticator_address = AztecAddress::from_field(witness[0]);

        // Get authenticator note
        let mut authenticator = storage.authenticators.at(authenticator_address).get_note().note;
        debug_log_format("authenticator.address: {}", [authenticator.address.to_field()]);
        debug_log_format("authenticator.enabled: {}", [authenticator.enabled.to_field()]);
        assert(authenticator.enabled, "authenticator not installed");

        // TODO: add mode 0x02 (enable) to allow recovery
        // this'd eliminate a waste of gas in deploying recovery authenticator beforehand.

        authenticator.validate(context, outer_hash)
        // true
    }

    #[private]
    fn install_authenticator(authenticator_address: AztecAddress, signing_pubkeys:[Field; INSTALL_KEYS_LEN]) {
        let this = context.this_address();
        let this_keys = get_public_keys(this);

        let mut authenticator = AuthenticatorNote::new(authenticator_address, true, this_keys.npk_m.hash());
        storage.authenticators.at(authenticator_address).initialize(&mut authenticator).emit(encode_and_encrypt_note_with_keys(&mut context, this_keys.ovpk_m, this_keys.ivpk_m, this));
        authenticator.install(&mut context, signing_pubkeys);
    }

    #[private]
    fn uninstall_authenticator(authenticator_address: AztecAddress) {
        let this = context.this_address();
        let this_keys = get_public_keys(this);

        let mut authenticator_note = storage.authenticators.at(authenticator_address).get_note().note;
        
        let mut new_authenticator_note = AuthenticatorNote::empty();
        storage.authenticators.at(authenticator_address).replace(&mut new_authenticator_note).emit(encode_and_encrypt_note_with_keys(&mut context, this_keys.ovpk_m, this_keys.ivpk_m, this));
        authenticator_note.uninstall(&mut context);
    }

    // Not sure if 2D nonce with mapping is necessary on Aztec
    #[private]
    #[internal]
    fn _validate_and_update_nonce(nonce: Field) {
        let this = context.this_address();
        let this_keys = get_public_keys(this);

        let mut nonce_note = storage.nonce.get_note().note;
        nonce_note.value = nonce_note.value + 1; 
        assert(nonce_note.value as u64 == nonce as u64, "invalid nonce");
       
        storage.nonce.replace(&mut nonce_note).emit(encode_and_encrypt_note_with_keys(&mut context, this_keys.ovpk_m, this_keys.ivpk_m, this));
    }

    unconstrained fn get_nonce() -> pub Field {
        storage.nonce.view_note().value 
    }

    unconstrained fn is_authenticator_installed(authenticator: AztecAddress) -> pub bool {
        storage.authenticators.at(authenticator).view_note().enabled
    }

}

