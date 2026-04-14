(** Linting engine. *)

type exclusion_stats = { rule : string; file : string }
(** A single suppressed issue. *)

type result = { issues : Rule.Run.result list; excluded : exclusion_stats list }
(** Analysis result. *)

val run :
  filter:Filter.t ->
  dune_describe:Dune.describe ->
  ?profiling:Profiling.t ->
  string ->
  result
(** [run ~filter ~dune_describe ?profiling project_root] runs all checks.
    Returns detected issues and a record of every suppressed issue. *)
