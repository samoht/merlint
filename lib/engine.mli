(** Linting engine. *)

type exclusion_stats = { rule : string; file : string }
(** A single suppressed issue. *)

type result = {
  issues : Rule.Run.result list;
  excluded : exclusion_stats list;
  files_analyzed : int;
  unchecked_files : string list;
}
(** Analysis result. {!field-files_analyzed} is the size of the file set the
    engine actually iterated -- either the [?analyze_set] supplied by the caller
    or every source file the project index found.

    {!field-unchecked_files} are the analysed files no typedtree could be had
    for, so the rules that read one could not run on them. They arrive two ways:
    nothing could say what to type the file against, which a build fixes, or the
    compiler read the source and refused it, which only editing the source
    fixes. A run with a non-empty list examined less than it was asked to, and a
    caller that reports "no issues" without saying so is reporting a different
    result than the one it obtained. Two kinds of file are not listed: one
    belonging to a platform- or config-gated stanza the host does not build,
    since no artefact is expected for it, and one outside the analysed set,
    since a project rule reaching past that set answers for its own evidence and
    no rule of this run was going to examine the file. *)

val run :
  ?domain_mgr:[> Eio.Domain_manager.ty ] Eio.Resource.t ->
  load_file:(string -> string) ->
  filter:Filter.t ->
  ?analyze_set:Fpath.t list ->
  ?analyze_roots:Fpath.t list ->
  index:(?pool:Eio.Executor_pool.t -> unit -> Project_index.t) ->
  ?profiling:Profiling.t ->
  ?bail:bool ->
  ?exclude:string list ->
  ?include_vendored:bool ->
  string ->
  result
(** [run ?domain_mgr ~load_file ~filter ?analyze_set ?analyze_roots ~index
     ?profiling ?bail ?exclude project_root] runs every rule that matches
    [filter] and returns the issues found. When [bail] is [true], the result
    keeps only the first issue in normal report order.

    [exclude] is a list of globs; any analyzed file matching one (against its
    path relative to [project_root], or the raw path) is dropped before
    analysis. Same matcher as [merlint.toml] exclusions.

    [load_file path] returns the source bytes of [path]; reached only by the
    parser-fallback path inside Merlin when no [.cmt] is present.

    [analyze_set] narrows file-scoped iteration to explicit files.
    [analyze_roots] adds every indexed source file below those directories. If
    both are omitted, iteration defaults to every source file the project index
    knows about.

    [include_vendored] keeps files under Dune [(vendored_dirs ...)] subtrees in
    the analysis set. They are dropped by default (the index scans them only so
    dependency edges resolve).

    [domain_mgr] enables parallelism. When given, [run] opens a single
    [Eio.Executor_pool] and shares it across the project-index build and every
    rule phase. [index ?pool ()] is forced exactly once inside that pool. *)
