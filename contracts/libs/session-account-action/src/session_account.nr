use dep::aztec::context::{PrivateContext, PublicContext};
use dep::aztec::state_vars::{Map, PublicMutable};
use dep::aztec::protocol_types::{address::AztecAddress, abis::function_selector::FunctionSelector, hash::pedersen_hash};

use dep::authwit::entrypoint::{app::AppPayload, fee::FeePayload};
use dep::authwit::auth::{IS_VALID_SELECTOR, compute_outer_authwit_hash};

use crate::approved_action::ApprovedAction;

struct SessionAccountActions<Context> {
  context: Context,
  is_valid_impl: fn(&mut PrivateContext, Field) -> bool,
  approved_actions: Map<Field, PublicMutable<ApprovedAction, Context>, Context>,
}

impl<Context> SessionAccountActions<Context> {
    pub fn init(
        context: Context,
        approved_actions_storage_slot: Field,
        is_valid_impl: fn(&mut PrivateContext, Field) -> bool
    ) -> Self {
        SessionAccountActions {
            context,
            is_valid_impl,
            approved_actions: Map::new(
                context,
                approved_actions_storage_slot,
                |context, slot| {
          PublicMutable::new(context, slot)
        }
            )
        }
    }
}

impl SessionAccountActions<&mut PrivateContext> {
    // docs:start:entrypoint
    pub fn entrypoint(self, app_payload: AppPayload, fee_payload: FeePayload) {
        let valid_fn = self.is_valid_impl;

        let fee_hash = fee_payload.hash();
        assert(valid_fn(self.context, fee_hash));
        fee_payload.execute_calls(self.context);
        self.context.end_setup();

        let app_hash = app_payload.hash();
        assert(valid_fn(self.context, app_hash));
        app_payload.execute_calls(self.context);
    }
    // docs:end:entrypoint

    // docs:start:spend_private_authwit
    pub fn spend_private_authwit(self, inner_hash: Field) -> Field {
        // The `inner_hash` is "siloed" with the `msg_sender` to ensure that only it can 
        // consume the message.
        // This ensures that contracts cannot consume messages that are not intended for them.
        let message_hash = compute_outer_authwit_hash(
            self.context.msg_sender(),
            self.context.chain_id(),
            self.context.version(),
            inner_hash
        );
        let valid_fn = self.is_valid_impl;
        assert(valid_fn(self.context, message_hash) == true, "Message not authorized by account");
        self.context.push_new_nullifier(message_hash, 0);
        IS_VALID_SELECTOR
    }
    // docs:end:spend_private_authwit
}

impl SessionAccountActions<&mut PublicContext> {
    // docs:start:spend_public_authwit
    pub fn spend_public_authwit(self, inner_hash: Field) -> Field {
        // The `inner_hash` is "siloed" with the `msg_sender` to ensure that only it can 
        // consume the message.
        // This ensures that contracts cannot consume messages that are not intended for them.
        let message_hash = compute_outer_authwit_hash(
            self.context.msg_sender(),
            self.context.chain_id(),
            self.context.version(),
            inner_hash
        );

        let action = self.approved_actions.at(message_hash).read();
        assert(action.is_valid, "Message not authorized by account");

        if (action.is_session) {
            let current_time = self.context.timestamp();
            assert((action.valid_from <= current_time) & (action.valid_until >= current_time), "Invalid time");
        }
    
        self.context.push_new_nullifier(message_hash, 0);
        IS_VALID_SELECTOR
    }
    // docs:end:spend_public_authwit

    // docs:start:approve_public_authwit
    pub fn approve_public_authwit(self, message_hash: Field, is_session:bool, valid_from:u64, valid_until:u64) {
        let current_time = self.context.timestamp();
        assert(valid_until >= valid_from, "invalid period");
        let action = ApprovedAction::new(true, is_session, valid_from, valid_until);
        self.approved_actions.at(message_hash).write(action);
    }
    // docs:end:approve_public_authwit
}
