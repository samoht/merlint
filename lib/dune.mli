(** Wrapper for dune commands. *)

type describe
(** Abstract type for dune describe results. *)

val describe : Fpath.t -> describe
(** [describe project_path] returns parsed dune describe output for a project.
*)

val ensure_project_built : Fpath.t -> (unit, string) result
(** [ensure_project_built project_path] ensures the project is built by running
    'dune build' if needed. *)

val is_executable : describe -> Fpath.t -> bool
(** [is_executable describe file_path] checks if a file is an executable (binary
    or test) - no .mli needed. *)

val get_project_files : describe -> Fpath.t list
(** [get_project_files describe] returns all project source files. *)

val get_executable_modules : describe -> string list
(** [get_executable_modules describe] gets executable module names from dune
    describe. *)

val get_lib_modules : describe -> string list
(** [get_lib_modules describe] gets library module names from dune describe. *)

val get_test_modules : describe -> string list
(** [get_test_modules describe] gets test module names from dune describe. *)

val merge : describe list -> describe
(** [merge describes] merges multiple describe values into one, deduplicating
    entries. *)

val exclude : string list -> describe -> describe
(** [exclude patterns describe] filters out files matching the given patterns
    from a describe. Patterns can be simple strings or use * for wildcards. *)

val create_synthetic : string list -> describe
(** [create_synthetic files] creates a synthetic describe for individual files
    passed on command line. *)

val get_libraries : describe -> (string * Fpath.t list) list
(** [get_libraries describe] returns the list of libraries with their files. *)

val get_tests : describe -> (string * Fpath.t list) list
(** [get_tests describe] returns the list of test stanzas with their files. *)
