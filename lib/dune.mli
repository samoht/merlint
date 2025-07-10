(** Wrapper for dune commands *)

type stanza_type = Library | Executable | Test

type stanza_info = {
  name : string;
  stanza_type : stanza_type;
  modules : string list;
}

val run_dune_describe : string -> (string, string) result
(** Run 'dune describe' and parse the output *)

val ensure_project_built : string -> (unit, string) result
(** Ensure the project is built by running 'dune build' if needed *)

val is_test_module : string -> stanza_info list -> bool
(** Check if a module name belongs to a test or executable stanza *)

val is_executable : string -> string -> bool
(** Check if a file is an executable (binary or test) - no .mli needed *)

val clear_cache : unit -> unit
(** Clear the dune describe cache *)

val get_executable_info : string -> string list
(** Get list of executable module names for the project *)

val get_project_files : string -> string list
(** Get all project source files using dune describe. Returns a list of .ml and
    .mli files. *)
