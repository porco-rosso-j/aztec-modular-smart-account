use crate::context::PrivateContext;
use crate::note::note_header::NoteHeader;
use dep::protocol_types::grumpkin_point::GrumpkinPoint;

// docs:start:note_interface
trait NoteInterface<N, M> {
    fn compute_nullifier(self, context: &mut PrivateContext) -> Field;

    fn compute_nullifier_without_context(self) -> Field;

    fn broadcast(self, context: &mut PrivateContext, slot: Field, ovpk_m: GrumpkinPoint, ivpk_m: GrumpkinPoint) -> ();

    // Autogenerated by the #[aztec(note)] macro unless it is overridden by a custom implementation
    fn serialize_content(self) -> [Field; N];

    // Autogenerated by the #[aztec(note)] macro unless it is overridden by a custom implementation
    fn deserialize_content(fields: [Field; N]) -> Self;

    // Autogenerated by the #[aztec(note)] macro unless it is overridden by a custom implementation
    fn compute_note_content_hash(self) -> Field;

    // Autogenerated by the #[aztec(note)] macro unless it is overridden by a custom implementation
    fn get_header(self) -> NoteHeader;

    // Autogenerated by the #[aztec(note)] macro unless it is overridden by a custom implementation
    fn set_header(&mut self, header: NoteHeader) -> ();

    // Autogenerated by the #[aztec(note)] macro unless it is overridden by a custom implementation
    fn get_note_type_id() -> Field;

    // Autogenerated by the #[aztec(note)] macro unless it is overridden by a custom implementation
    fn to_be_bytes(self, storage_slot: Field) -> [u8; M];
}
// docs:end:note_interface

