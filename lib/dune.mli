(** Wrapper for dune commands *)

type stanza_type = 
  | Library
  | Executable
  | Test

type stanza_info = {
  name: string;
  stanza_type: stanza_type;
  modules: string list;
}

(** Run 'dune describe' and parse the output *)
val run_dune_describe : string -> (string, string) result

(** Ensure the project is built by running 'dune build' if needed *)
val ensure_project_built : string -> (unit, string) result

(** Check if a module name belongs to a test or executable stanza *)
val is_test_or_binary : string -> stanza_info list -> bool