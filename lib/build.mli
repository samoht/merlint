(** Shell out to [dune build] for the artefacts typedtree-backed rules need.

    One operation: a warm-up before a run, scoped to the directories that run
    analyses, so [@check] has produced the [.cmi] files a file is typed against
    and the [.cmt] / [.cmti] that answer for it directly. An artefact left
    describing source that has since changed needs no attention here -- the
    source is typechecked in its place. *)

val ensure_project_built :
  root:Fpath.t ->
  scopes:Fpath.t list ->
  _ Eio.Process.mgr ->
  (unit, string) result
(** [ensure_project_built ~root ~scopes mgr] runs a single
    [dune build --root <root>] over the [check] alias of every directory in
    [scopes]: [@<dir>/check] for a directory below [root], and the bare [@check]
    for [root] itself or for empty [scopes]. Dune resolves a scoped alias
    against the whole workspace, so cross-package dependencies still build and
    only the targets narrow. The [check] alias is what produces [.cmt] artefacts
    for every module (including wrapped executables and tests where a plain
    [dune build] only emits native code). Stderr is suppressed unless the
    [merlint.build] log source is at debug level. Returns [Ok ()] on dune exit
    0, and [Error msg] on a scope [root] does not contain -- which has no alias
    under it, and which the whole-tree alias would build past without saying so
    -- or on any other dune exit. *)

val cmt_artefact : root:string -> Fpath.t -> (string * bool) option
(** [cmt_artefact ~root file] is the [.cmt] / [.cmti] path for [file] under
    [root]'s [_build], paired with [true] when the artefact records the current
    source path and digest. [None] when no artefact exists or the file cannot be
    resolved. *)

type source_status =
  | Compiled  (** Source exists and its [.cmt] / [.cmti] is up to date. *)
  | Not_compiled
      (** Source exists but has no fresh [.cmt] / [.cmti] artefact, so
          typedtree-backed analysis cannot run on it yet. *)
  | Skipped
      (** Source exists on disk but the project index did not capture it (e.g. a
          roots-scoped scan that dropped a sibling), so a [.mli]/[.ml] check
          must not treat it as absent. Distinct from {!constructor-Missing}. *)
  | Missing  (** No such source file exists on disk. *)

val source_status :
  root:string -> index:Project_index.t -> Fpath.t -> source_status
(** [source_status ~root ~index file] classifies [file] for typedtree-backed
    analysis. Presence comes from {!Project_index.source_presence}, which
    distinguishes an indexed source, one merely {!constructor-Skipped} (on disk
    but not indexed), and a genuinely {!constructor-Missing} one; compilation
    freshness checks the source path and digest recorded by the [.cmt] / [.cmti]
    under [root]'s [_build]. Rules use this to tell a genuinely absent interface
    ({!constructor-Missing}) from one that merely lacks a fresh artefact
    ({!constructor-Not_compiled}) or escaped indexing ({!constructor-Skipped}).
*)
