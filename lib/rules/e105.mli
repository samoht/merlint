(** E105: Catch-All Exception Handlers

    This rule detects wildcard exception handlers that can hide important errors
    and make debugging difficult. *)

val rule : Rule.t
(** [rule] is the E105 rule definition. *)
