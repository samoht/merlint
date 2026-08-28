(** Linting engine. *)

type exclusion_stats = { rule : string; file : string }
(** A single suppressed issue. *)

(** Why a unit of work did not finish. {!constructor-Crashed} is a defect in
    merlint: the rule's body raised. {!constructor-Unevaluated} is a fact the
    rule needed and the project index did not hold, so the rule ran to the end
    and still could not decide. The two are apart because they are fixed apart
    -- one by changing merlint, the other by pointing this run at the tree the
    missing fact lives in. *)
type incomplete = Crashed | Unevaluated

type failure = {
  rule : string option;
  file : string option;
  kind : incomplete;
  error : string;
}
(** One unit of work a run started and did not finish. [rule] is the code of the
    rule whose body raised or could not decide, and [None] when what raised was
    the whole file's analysis, which is every rule of the run over that file.
    [file] is the source being read, and [error] the exception or the question
    that went undecided. *)

type result = {
  issues : Rule.Run.result list;
  excluded : exclusion_stats list;
  files_analyzed : int;
  rules_applied : int;
  unresolved_files : string list;
  uncompilable_files : string list;
  unclaimed_files : string list;
  failed : failure list;
}
(** Analysis result. {!field-files_analyzed} is the size of the file set the
    engine actually iterated -- either the [?analyze_set] supplied by the caller
    or every source file the project index found.

    {!field-rules_applied} is how many distinct rules this run actually ran: a
    project rule that enumerated at least one unit, a file rule that had a file
    to read, a pass rule whose file carried a typedtree. It is not the number of
    rules the filter enabled. A run whose typedtree-backed rules were all
    skipped applied fewer rules than one that read every file, and reporting the
    enabled count for both would report a rule set that shrank as one that did
    not.

    {!field-unresolved_files} and {!field-uncompilable_files} are the analysed
    files no typedtree could be had for, so the rules that read one could not
    run on them. They are apart because the remedy differs: nothing could say
    what to type an unresolved file against, which a build fixes, while the
    compiler read an uncompilable one and refused it, which only editing the
    source fixes. A run with either list non-empty examined less than it was
    asked to, and a caller that reports "no issues" without saying so is
    reporting a different result than the one it obtained. Two kinds of file are
    not listed: one belonging to a platform- or config-gated stanza the host
    does not build, since no artefact is expected for it, and one outside the
    analysed set, since a project rule reaching past that set answers for its
    own evidence and no rule of this run was going to examine the file.

    {!field-unclaimed_files} are the source files the run was pointed at that no
    dune stanza claims, so the engine never iterated them and no rule saw them
    at all. Reporting them is what makes the run's own numbers add up:
    {!field-files_analyzed} plus this list accounts for every [.ml] / [.mli] in
    the walked tree, so a discovery gap moves a number instead of passing
    unnoticed. A directory the run was pointed at contributes the sources under
    it nothing compiles; a file named in [?analyze_set] contributes itself when
    no stanza claims it. The orphans of a directory the caller did not name stay
    out of a file-scoped run, which is the part of "an explicit set is the
    caller's own accounting" that holds -- a file the caller did name is
    precisely the one it is owed an answer about.

    {!field-failed} is the work this run began and did not finish: a rule whose
    body raised, a file whose whole analysis did, or a rule that could not
    decide because the project index did not hold a fact it needed. The result
    of a rule that crashed, of a rule that could not evaluate, and of a rule
    that ran and found nothing are all the same empty list, so a run that
    counted only findings reported the three the same way; a crashed rule is
    also not counted in {!field-rules_applied}, since it did not apply to
    anything. Nothing here is a statement about the code, and each member leaves
    the run's verdict short by however much the rule would have said. See
    {!type-incomplete} for which of the two reasons a member carries. *)

val run :
  ?domain_mgr:[> Eio.Domain_manager.ty ] Eio.Resource.t ->
  load_file:(string -> string) ->
  filter:Filter.t ->
  ?analyze_set:Fpath.t list ->
  ?analyze_roots:Fpath.t list ->
  index:(?pool:Eio.Executor_pool.t -> unit -> Project_index.t) ->
  ?index_is_partial:bool ->
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

    [index_is_partial] says that [index] scans part of the source tree only, so
    a lookup that resolves to nothing may be a fact this scan never gathered
    rather than one that does not exist. Rules read it through
    {!Context.index_is_partial}. Defaults to [false]: a caller that narrows the
    index is the one that knows it did.

    [include_vendored] keeps files under Dune [(vendored_dirs ...)] subtrees in
    the analysis set. They are dropped by default (the index scans them only so
    dependency edges resolve).

    [domain_mgr] enables parallelism. When given, [run] opens a single
    [Eio.Executor_pool] and shares it across the project-index build and every
    rule phase. [index ?pool ()] is forced exactly once inside that pool. *)
