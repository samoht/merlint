(** Shell out to [dune build] for the artefacts typedtree-backed rules need.

    One operation: a warm-up before a run, scoped to the directories that run
    analyses, so [@check] has produced the [.cmi] files a file is typed against
    and the [.cmt] / [.cmti] that answer for it directly. An artefact left
    describing source that has since changed needs no attention here -- the
    source is typechecked in its place. *)

(** Why a build did not produce the artefacts that were asked for.

    The three are apart because a caller does different things about them, and
    dune tells them apart only on stderr: it reports a busy root and code that
    does not compile with the same exit code. *)
type unbuilt =
  | Contended of string
      (** Another dune holds this root, so the build never started. Nothing is
          wrong with the tree and nothing about it has been established; the
          same command run later does the work. *)
  | Broken of string
      (** The build ran and the project did not build. What dune said is the
          message, and it is the thing to fix. *)
  | Unscoped of string
      (** A scope [root] does not contain, so there is no [check] alias under it
          to ask for. merlint's own argument is wrong, and the whole-tree alias
          would build past it without saying so. *)

val message : unbuilt -> string
(** [message unbuilt] is the sentence to show a user: what did not happen, and
    what dune said about it. *)

val ensure_project_built :
  root:Fpath.t ->
  scopes:Fpath.t list ->
  targets:Fpath.t list ->
  _ Eio.Process.mgr ->
  (unit, unbuilt) result
(** [ensure_project_built ~root ~scopes ~targets mgr] runs a single
    [dune build --root <root>] over each exact [target] and the [check] alias of
    each directory in [scopes]. A directory below [root] becomes
    [@_build/default/<dir>/check]; [root] itself becomes
    [@_build/default/check]. Empty [scopes] and [targets] build that same root
    alias. Naming the context matches the [_build/default] typedtrees merlint
    reads and avoids building unrelated workspace contexts. Exact targets are
    what make executable and test repairs independent of whether a composed
    workspace gives their directory alias any members. Scoped aliases retain
    Dune's complete [.cmt] production, including implementation typedtrees for
    executables whose link target alone does not request [-bin-annot]. Exact
    targets are also named below [_build/default], so they do not request the
    same target from every context in a composed workspace.

    Dune's stderr is captured rather than discarded, because it is the only
    place the difference between {!constructor-Contended} and
    {!constructor-Broken} is written: both exit 1. It never reaches the terminal
    from here either way -- the caller decides what to show. *)

val cmt_artefact :
  root:string ->
  Fpath.t ->
  (string * (unit, Merlin.Cmt.Unusable.t) result) option
(** [cmt_artefact ~root file] is the [.cmt] / [.cmti] path for [file] under
    [root]'s [_build], paired with [Ok ()] when the artefact describes all of
    the current source and the reason it does not otherwise. [None] when no
    artefact exists or the file cannot be resolved. *)

type source_status =
  | Compiled  (** Source exists and its [.cmt] / [.cmti] is up to date. *)
  | Not_compiled
      (** Source exists but has no fresh [.cmt] / [.cmti] artefact, so
          typedtree-backed analysis cannot run on it yet. A build produces one.
      *)
  | Uncompilable
      (** Source exists and the compiler refused it: the artefact left for it is
          the part of the unit typed before the error, so no typedtree answers
          for the file and no build will produce one until the source is fixed.
          Distinct from {!constructor-Not_compiled}, which a build clears. *)
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
    but not indexed), and a genuinely {!constructor-Missing} one; what the
    [.cmt] / [.cmti] under [root]'s [_build] can answer for comes from
    {!Merlin.Cmt.status}. Rules use this to tell a genuinely absent interface
    ({!constructor-Missing}) from one that merely lacks a fresh artefact
    ({!constructor-Not_compiled}), one whose source the compiler refused
    ({!constructor-Uncompilable}), or one that escaped indexing
    ({!constructor-Skipped}). *)
