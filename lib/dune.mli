(** Wrapper for dune commands *)

type describe = Sexplib0.Sexp.t
(** Parsed dune describe output *)

val describe : string -> describe
(** Get parsed dune describe output for a project, using cache when possible *)

val ensure_project_built : string -> (unit, string) result
(** Ensure the project is built by running 'dune build' if needed *)

val is_executable : describe -> string -> bool
(** Check if a file is an executable (binary or test) - no .mli needed *)

val get_executable_info : describe -> string list
(** Get list of executable module names for the project *)

val get_project_files : describe -> string list
(** Get all project source files using dune describe. Returns a list of .ml and
    .mli files. *)

val get_lib_modules : describe -> string list
(** Get library module names from dune describe *)

val get_test_modules : describe -> string list
(** Get test module names from dune describe *)
