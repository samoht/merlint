(** Shell out to [dune build] for the artefacts typedtree-backed rules need.

    Two operations:
    - whole-project warm-up before a run ([ensure_project_built]) so [@check]
      has produced [.cmt] / [.cmti] for every module;
    - per-file refresh ([refresh_stale_cmt_targets]) when only a handful of
      sources changed since the last warm-up. *)

val ensure_project_built :
  path:string -> _ Eio.Process.mgr -> (unit, string) result
(** [ensure_project_built ~path mgr] runs [dune build --root <path> @check]. The
    [@check] alias is what produces [.cmt] artefacts for every module (including
    wrapped executables and tests where a plain [dune build] only emits native
    code). Stderr is suppressed unless the [merlint.build] log source is at
    debug level. Returns [Ok ()] on dune exit 0, [Error msg] otherwise. *)

val refresh_stale_cmt_targets :
  path:string ->
  files:Fpath.t list ->
  _ Eio.Process.mgr ->
  (unit, string) result
(** [refresh_stale_cmt_targets ~path ~files mgr] re-builds the [.cmt] / [.cmti]
    targets whose mtime is older than their source. Files whose [.cmt] is
    already fresh, or whose [.cmt] cannot be located in [_build/default], are
    skipped. Returns [Ok ()] when the (possibly empty) target list builds
    cleanly. *)

type source_status =
  | Compiled  (** Source exists and its [.cmt] / [.cmti] is up to date. *)
  | Not_compiled
      (** Source exists but has no fresh [.cmt] / [.cmti] artefact, so
          typedtree-backed analysis cannot run on it yet. *)
  | Missing  (** No such source file is known to the project. *)

val source_status :
  root:string -> index:Project_index.t -> Fpath.t -> source_status
(** [source_status ~root ~index file] classifies [file] for typedtree-backed
    analysis. Existence comes from [index] ({!Project_index.mem_source_file}),
    not a filesystem stat; compilation freshness compares the [.cmt] / [.cmti]
    under [root]'s [_build] against the source mtime. Rules use this to tell a
    genuinely absent interface ({!constructor-Missing}) from one that merely
    lacks a fresh artefact ({!constructor-Not_compiled}). *)
