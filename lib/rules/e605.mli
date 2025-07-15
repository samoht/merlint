(** E605: Missing Test File

    This rule ensures that library modules have corresponding test files. Each
    library module should have a test file to ensure proper testing coverage. *)

val check : Dune.describe -> string list -> Issue.t list
(** [check dune_data files] checks if library modules have corresponding test
    files. Returns a list of issues for missing test files. *)

(** {2 Helper functions exposed for E610 and E615} *)

val is_local_library : Sexplib0.Sexp.t list -> bool
val is_generated_module : Sexplib0.Sexp.t list -> bool
val extract_module_name : Sexplib0.Sexp.t list -> string option
val process_module : Sexplib0.Sexp.t -> string option
val extract_modules : Sexplib0.Sexp.t -> string list
val process_library_fields : Sexplib0.Sexp.t -> string list
val extract_library_modules : Sexplib0.Sexp.t -> string list
val get_lib_modules : Sexplib0.Sexp.t -> string list
val extract_test_modules : Sexplib0.Sexp.t -> string list
val get_test_modules : Sexplib0.Sexp.t -> string list
