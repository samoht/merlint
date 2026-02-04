(** Linting engine. *)

val run :
  filter:Filter.t ->
  dune_describe:Dune.describe ->
  ?profiling:Profiling.t ->
  string ->
  Rule.Run.result list
(** [run ~filter ~dune_describe ?profiling project_root] runs all checks on a
    project. Runs all enabled rules using the given dune describe for project
    structure. If [profiling] is provided, timing data will be collected.
    Returns a sorted list of issues found. *)
