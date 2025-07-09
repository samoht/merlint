(** Merlin interface for code analysis

    This module provides the interface to run Merlin and analyze OCaml files for
    various code quality issues. *)

val analyze_file : Config.t -> string -> (Issue.t list, string) result

val find_project_root : string -> string
(** [find_project_root file] finds the project root by looking for dune-project
*)
