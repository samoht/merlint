(** E105: Catch-All Exception Handlers

    This rule detects catch-all exception handlers (try...with _ ->) which can
    hide important errors and make debugging difficult. *)

val rule : Rule.t
(** The E105 rule definition *)
