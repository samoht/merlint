(** AST-based checks that require deeper analysis than typedtree provides *)

val analyze_file : string -> Issue.t list
(** [analyze_file filename] analyzes the given OCaml source file and returns a
    list of issues found. Currently detects:
    - E105: Catch-all exception handlers (try ... with _ -> ...) *)
