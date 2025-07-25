(** Linting engine. *)

val get_project_root : string -> string
(** [get_project_root path] finds the project root by looking for dune-project
    file. *)

val run :
  filter:Filter.t ->
  dune_describe:Dune.describe ->
  string ->
  Rule.Run.result list
(** [run ~filter ~dune_describe project_root] runs all checks on a project. Runs
    all enabled rules using the given dune describe for project structure.
    Returns a sorted list of issues found. *)
