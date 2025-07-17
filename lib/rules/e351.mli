(** E351: Global Mutable State

    This rule detects global mutable state (refs, arrays) defined at the module
    level. Global mutable state makes code harder to test and reason about. *)

val rule : Rule.t
(** The E351 rule definition *)
