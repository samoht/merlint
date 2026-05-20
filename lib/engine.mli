(** Linting engine. *)

type exclusion_stats = { rule : string; file : string }
(** A single suppressed issue. *)

type result = {
  issues : Rule.Run.result list;
  excluded : exclusion_stats list;
  files_analyzed : int;
}
(** Analysis result. {!field-files_analyzed} is the size of the file set the
    engine actually iterated -- either the [?analyze_set] supplied by the caller
    or every source file the project index found. *)

val run :
  ?domain_mgr:[> Eio.Domain_manager.ty ] Eio.Resource.t ->
  load_file:(string -> string) ->
  filter:Filter.t ->
  ?analyze_set:Fpath.t list ->
  ?analyze_roots:Fpath.t list ->
  index:(?pool:Eio.Executor_pool.t -> unit -> Project_index.t) ->
  ?profiling:Profiling.t ->
  ?bail:bool ->
  string ->
  result
(** [run ?domain_mgr ~load_file ~filter ?analyze_set ?analyze_roots ~index
     ?profiling ?bail project_root] runs every rule that matches [filter] and
    returns the issues found. When [bail] is [true], the result keeps only the
    first issue in normal report order.

    [load_file path] returns the source bytes of [path]; reached only by the
    parser-fallback path inside Merlin when no [.cmt] is present.

    [analyze_set] narrows file-scoped iteration to explicit files.
    [analyze_roots] adds every indexed source file below those directories. If
    both are omitted, iteration defaults to every source file the project index
    knows about.

    [domain_mgr] enables parallelism. When given, [run] opens a single
    [Eio.Executor_pool] and shares it across the project-index build and every
    rule phase. [index ?pool ()] is forced exactly once inside that pool. *)
