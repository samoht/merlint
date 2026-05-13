(** E505: Missing MLI File

    This rule ensures that library modules have corresponding .mli files.
    Library modules should have interface files for proper encapsulation. *)

val rule : Rule.t
(** [rule] is the E505 rule definition. *)
