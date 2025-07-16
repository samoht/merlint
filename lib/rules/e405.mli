(** E405: Missing Type Documentation

    This rule checks that public types have proper documentation. Types exposed
    in .mli files should be documented for API clarity. *)

val check : Context.file -> Issue.t list
(** [check files] checks if public types have documentation. Returns a list of
    issues for undocumented types. *)
