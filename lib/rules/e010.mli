(** E010: Deep Nesting

    This rule detects code with excessive nesting depth. Deep nesting makes code
    harder to read and understand. *)

val rule : Rule.t
(** [rule] is the E010 rule definition. *)
