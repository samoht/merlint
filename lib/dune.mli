(** Wrapper for dune commands *)

type describe
(** Abstract type for dune describe results *)

val describe : string -> describe
(** Get parsed dune describe output for a project, using cache when possible *)

val ensure_project_built : string -> (unit, string) result
(** Ensure the project is built by running 'dune build' if needed *)

val is_executable : describe -> string -> bool
(** Check if a file is an executable (binary or test) - no .mli needed *)

val get_project_files : describe -> string list
(** Get all project source files using dune describe. Returns a list of .ml and
    .mli files. *)

val get_lib_modules : describe -> string list
(** Get library module names from dune describe *)

val get_test_modules : describe -> string list
(** Get test module names from dune describe *)

val libraries : string -> (string * string list) list
(** Get all libraries in the project Returns a list of (library_name,
    source_files) pairs *)

val executables : string -> (string * string list) list
(** Get all executables in the project Returns a list of (executable_name,
    source_files) pairs The executable_name is the main entry point *)

val tests : string -> (string * string list) list
(** Get all tests in the project Returns a list of (test_name, source_files)
    pairs The test_name is the main entry point *)

val merge : describe list -> describe
(** Merge multiple describe values into one, deduplicating entries *)

val exclude : string list -> describe -> describe
(** Filter out files matching the given patterns from a describe. Patterns can
    be simple strings or use * for wildcards. *)

val create_synthetic : string list -> describe
(** Create a synthetic describe for individual files passed on command line *)
