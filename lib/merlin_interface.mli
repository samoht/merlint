(** Merlin interface for code analysis

    This module provides the interface to run Merlin and analyze OCaml files for
    various code quality violations. *)

val analyze_file :
  Cyclomatic_complexity.config -> string -> (Violation.t list, string) result
