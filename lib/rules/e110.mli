(** E110: Silenced Warning

    This rule detects code that silences warnings instead of fixing them.
    Warnings should be addressed rather than suppressed. *)

val rule : Rule.t
(** [rule] is the E110 rule definition. *)
