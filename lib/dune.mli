(** Wrapper for dune commands *)

type describe = Sexplib0.Sexp.t
(** Parsed dune describe output *)

val run_dune_describe : string -> (string, string) result
(** Run 'dune describe' and return the raw output *)

val describe : string -> describe
(** Get parsed dune describe output for a project, using cache when possible *)

val ensure_project_built : string -> (unit, string) result
(** Ensure the project is built by running 'dune build' if needed *)

val is_executable : string -> string -> bool
(** Check if a file is an executable (binary or test) - no .mli needed *)

val clear_cache : unit -> unit
(** Clear the dune describe cache *)

val get_executable_info : string -> string list
(** Get list of executable module names for the project *)

val get_project_files : string -> string list
(** Get all project source files using dune describe. Returns a list of .ml and
    .mli files. *)
