(** E325: Function Naming Convention

    This rule ensures that functions follow naming conventions:
    - get_* functions should not return option types
    - find_* functions should return option types *)

val rule : Rule.t
(** [rule] is the E325 rule definition. *)
