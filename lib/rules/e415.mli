(** E415: Missing Exception Documentation

    This rule checks that public exceptions have proper documentation.
    Exceptions exposed in .mli files should be documented for API clarity. *)

val rule : Rule.t
(** [rule] is the E415 rule definition. *)
