(** E610: Test Without Library

    This rule ensures that test files have corresponding library modules.
    Orphaned test files should be removed or their library modules should be
    created. *)

val rule : Rule.t
(** [rule] is the E610 rule definition. *)
