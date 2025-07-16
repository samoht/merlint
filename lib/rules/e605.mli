(** E605: Missing Test File

    This rule ensures that library modules have corresponding test files. Each
    library module should have a test file to ensure proper testing coverage. *)

val check : Context.t -> Issue.t list
(** [check ctx] checks if library modules have corresponding test files. Returns
    a list of issues for missing test files. *)
