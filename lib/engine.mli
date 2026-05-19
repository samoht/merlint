(** Linting engine. *)

type exclusion_stats = { rule : string; file : string }
(** A single suppressed issue. *)

type result = { issues : Rule.Run.result list; excluded : exclusion_stats list }
(** Analysis result. *)

val run :
  ?domain_mgr:[> Eio.Domain_manager.ty ] Eio.Resource.t ->
  load_file:(string -> string) ->
  filter:Filter.t ->
  dune_describe:Dune_describe.describe ->
  ?analyze_set:Fpath.t list ->
  index:(?pool:Eio.Executor_pool.t -> unit -> Project_index.t) ->
  ?profiling:Profiling.t ->
  string ->
  result
(** [run ?domain_mgr ~load_file ~filter ~dune_describe ?analyze_set ~index
     ?profiling project_root] runs every rule that matches [filter] and returns
    the issues found.

    [load_file path] returns the source bytes of [path]; reached only by the
    parser-fallback path inside Merlin when no [.cmt] is present.

    [dune_describe] is the project-wide view; project-scoped rules need it to
    reflect the whole project even on a single-file invocation. [analyze_set]
    narrows what file-scoped rules iterate -- defaults to every file in
    [dune_describe].

    [domain_mgr] enables parallelism. When given, [run] opens a single
    [Eio.Executor_pool] and shares it across the project-index build and every
    rule phase. [index ?pool ()] is forced exactly once inside that pool. *)
