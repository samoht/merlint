(** E410: Missing Value Documentation

    This rule checks that public values have proper documentation. Values
    exposed in .mli files should be documented for API clarity. *)

val check : Context.t -> Issue.t list
(** [check files] checks if public values have documentation. Returns a list of
    issues for undocumented values. *)
