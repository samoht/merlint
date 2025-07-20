(** Linting engine *)

val get_project_root : string -> string
(** Find the project root by looking for dune-project file. Given a file or
    directory path, searches upward for dune-project. *)

val run :
  filter:Filter.t ->
  dune_describe:Dune.describe ->
  string ->
  Rule.Run.result list
(** Run all checks on a project. [run ~filter ~dune_describe project_root] runs
    all enabled rules using the given dune describe for project structure.
    Returns a sorted list of issues found. *)
