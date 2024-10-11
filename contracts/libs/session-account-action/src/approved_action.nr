
use dep::aztec::protocol_types::traits::{Serialize, Deserialize};

global APPROVE_ACTION_LEN: Field = 4; 

struct ApprovedAction {
    is_valid: bool,
    is_session: bool,
    valid_from: u64,
    valid_until: u64
}

impl ApprovedAction {
    pub fn new(
       is_valid: bool,
       is_session: bool,
       valid_from: u64,
       valid_until: u64
    ) -> Self {
        ApprovedAction {
            is_valid,
            is_session,
            valid_from,
            valid_until
        }
    }
}


impl Deserialize<APPROVE_ACTION_LEN> for ApprovedAction {
    fn deserialize(fields: [Field; APPROVE_ACTION_LEN]) -> Self {
        ApprovedAction { 
            is_valid: fields[0] as bool,
            is_session: fields[1] as bool,
            valid_from: fields[2] as u64,
            valid_until: fields[3] as u64,
         }
    }
}

impl Serialize<APPROVE_ACTION_LEN> for ApprovedAction {
    fn serialize(self) -> [Field; APPROVE_ACTION_LEN] {
        [
            self.is_valid as Field, 
            self.is_session as Field,
            self.valid_from as Field,
            self.valid_until as Field,
        ]
    }
}