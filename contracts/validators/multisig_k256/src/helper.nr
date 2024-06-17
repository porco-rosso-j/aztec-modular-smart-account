
    pub fn u8_to_u8_32(arr: [u8]) -> [u8; 32] {
       let mut as_field: [u8; 32] = [0 as u8; 32];
       for i in 0..32 {
          as_field[i] = arr[i];
       }
       as_field
    }