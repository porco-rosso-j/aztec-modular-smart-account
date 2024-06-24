mod validator_note;

global MAX_WITNESS_NOTE_LEN: Field = 500;
global MODE_DEFAULT = 0;
global MODE_CUSTOM = 1;

contract KernelAccount {
    use dep::aztec::prelude::{AztecAddress, FunctionSelector, NoteHeader, NoteGetterOptions, Map, PrivateContext, PrivateMutable, SharedMutable};
    use dep::value_note::value_note::ValueNote;
    use dep::address_note::address_note::AddressNote;

    use dep::aztec::protocol_types::abis::call_context::CallContext;
    use dep::std;

    use dep::authwit::{
        entrypoint::{app::AppPayload, fee::FeePayload}, account::AccountActions,
        auth_witness::get_auth_witness
    }; 

    use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};

    use crate::validator_note::{ValidatorNote, INSTALL_KEYS_LEN};
    use crate::{MAX_WITNESS_NOTE_LEN, MODE_DEFAULT, MODE_CUSTOM};
    use dep::helper::{get_viewing_pubkeys, get_viewing_pubkeys_and_npkm_hash};
    
    #[aztec(storage)]
    struct Storage {
        default_validator: PrivateMutable<AddressNote>,
        validators: Map<AztecAddress, PrivateMutable<ValidatorNote>>,
        nonce: PrivateMutable<ValueNote>,
        // registry
    }

    global ACCOUNT_ACTIONS_STORAGE_SLOT = 4;

    // Creates a new account out of an ECDSA public key to use for signature verification
    #[aztec(private)]
    #[aztec(initializer)]
    fn constructor(default_validator: AztecAddress, signing_pubkeys:[Field; INSTALL_KEYS_LEN]) {
        debug_log("constructor");
        debug_log_format("default_validator {0}", [default_validator.to_field()]);
        debug_log_format("signing_pubkeys[0] {0}", [signing_pubkeys[0]]);
        debug_log_format("signing_pubkeys[1] {0}", [signing_pubkeys[1]]);
        let header = context.get_header();
        let this = context.this_address();
        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, this);

        let mut nonce_note = ValueNote::new(0, npk_m_hash);
        storage.nonce.initialize(&mut nonce_note, ovpk_m, ivpk_m);

        let mut default_validator_note = AddressNote::new(default_validator, npk_m_hash);
        storage.default_validator.initialize(&mut default_validator_note, ovpk_m, ivpk_m);
        
        let mut validator_note = ValidatorNote::new(default_validator, true, npk_m_hash);
        storage.validators.at(default_validator).initialize(&mut validator_note, ovpk_m, ivpk_m);
        validator_note.install(&mut context, signing_pubkeys);
    }

    // Note: If you globally change the entrypoint signature don't forget to update default_entrypoint.ts
    #[aztec(private)]
    fn entrypoint(app_payload: AppPayload, fee_payload: FeePayload) {
        let actions = AccountActions::init(&mut context, ACCOUNT_ACTIONS_STORAGE_SLOT, is_valid_impl);
        actions.entrypoint(app_payload, fee_payload);

        // validate and increment nonce
        context.call_private_function(
            context.this_address(),
            FunctionSelector::from_signature("_validate_and_update_nonce(Field)"), 
            [app_payload.nonce]
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

    #[contract_library_method]
    fn is_valid_impl(context: &mut PrivateContext, outer_hash: Field) -> bool {
        // Load public key from storage
        let storage = Storage::init(context);
        let (ovpk_m, ivpk_m) = get_viewing_pubkeys(context, context.this_address());

        // Load auth witness
        let witness: [Field; MAX_WITNESS_NOTE_LEN] = get_auth_witness(outer_hash);
        let mode = witness[0]; // 0x00: default, 0x01: custom, 0x02: add a new validator
        
        let mut validator = ValidatorNote::empty();

        if mode == MODE_DEFAULT {
            let default = storage.default_validator.get_note(ovpk_m, ivpk_m);
            validator = storage.validators.at(default.address).get_note(ovpk_m, ivpk_m);

        } else if mode == MODE_CUSTOM {
           let validator_address = AztecAddress::from_field(witness[1]);
            validator = storage.validators.at(validator_address).get_note(ovpk_m, ivpk_m);
            assert(validator.enabled, "validator not installed");
        } 

        // TODO: add mode 0x02 (enable) to allow recovery
        // this'd eliminate a waste of gas in deploying recovery validator beforehand.

        validator.validate(context, mode, outer_hash)
        
    }

    #[aztec(private)]
    fn install_validator(validator_address: AztecAddress, signing_pubkeys:[Field; INSTALL_KEYS_LEN]) {

        debug_log("ecdsa install");
        debug_log_format("validator_address {0}", [validator_address.to_field()]);
        debug_log_format("signing_pubkeys[0] {0}", [signing_pubkeys[0]]);
        debug_log_format("signing_pubkeys[1] {0}", [signing_pubkeys[1]]);

        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, context.this_address());

        let mut validator = ValidatorNote::new(validator_address, true, npk_m_hash);
        storage.validators.at(validator_address).initialize(&mut validator, ovpk_m, ivpk_m);
        validator.install(&mut context, signing_pubkeys);
    }

    #[aztec(private)]
    fn uninstall_validator(validator_address: AztecAddress) {
        let (ovpk_m, ivpk_m, npk_m_hash) = get_viewing_pubkeys_and_npkm_hash(&mut context, context.this_address());
        
        let mut validator = ValidatorNote::empty();
        storage.validators.at(validator_address).replace(&mut validator, ovpk_m, ivpk_m);
        validator.uninstall(&mut context);
    }

    // Not sure if 2D nonce with mapping is necessary on Aztec
    #[aztec(private)]
    #[aztec(internal)]
    fn _validate_and_update_nonce(nonce: Field) {
        let (ovpk_m, ivpk_m) = get_viewing_pubkeys(&mut context, context.this_address());

        let mut nonce_note = storage.nonce.get_note(ovpk_m, ivpk_m);
        nonce_note.value = nonce_note.value + 1; 
        assert(nonce_note.value as u64 == nonce as u64, "invalid nonce");
       
        storage.nonce.replace(&mut nonce_note, ovpk_m, ivpk_m);
    }

    unconstrained fn get_nonce() -> pub Field {
        storage.nonce.view_note().value 
    }

    unconstrained fn is_validator_installed(validator: AztecAddress) -> pub bool {
        storage.validators.at(validator).view_note().enabled
    }

}

