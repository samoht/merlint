(** E600: Test Module Convention

    This rule ensures that test files follow proper conventions. Test modules
    should export 'suite' not module name. *)

val rule : Rule.t
(** The E600 rule definition *)
