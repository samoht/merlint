(** E415: Missing Exception Documentation

    This rule checks that public exceptions have proper documentation.
    Exceptions exposed in .mli files should be documented for API clarity. *)

val check : string list -> Issue.t list
(** [check files] checks if public exceptions have documentation. Returns a list
    of issues for undocumented exceptions. *)
