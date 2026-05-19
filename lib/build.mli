(** Shell out to [dune build] for the artefacts typedtree-backed rules need.

    Two operations:
    - whole-project warm-up before a run ([ensure_project_built]) so [@check]
      has produced [.cmt] / [.cmti] for every module;
    - per-file refresh ([refresh_stale_cmt_targets]) when only a handful of
      sources changed since the last warm-up. *)

val ensure_project_built :
  path:string -> _ Eio.Process.mgr -> (unit, string) result
(** [ensure_project_built ~path mgr] runs [dune build --root <path> @check].
    The [@check] alias is what produces [.cmt] artefacts for every module
    (including wrapped executables and tests where a plain [dune build] only
    emits native code). Stderr is suppressed unless the [merlint.build]
    log source is at debug level. Returns [Ok ()] on dune exit 0, [Error
    msg] otherwise. *)

val refresh_stale_cmt_targets :
  path:string ->
  files:Fpath.t list ->
  _ Eio.Process.mgr ->
  (unit, string) result
(** [refresh_stale_cmt_targets ~path ~files mgr] re-builds the [.cmt] /
    [.cmti] targets whose mtime is older than their source. Files whose
    [.cmt] is already fresh, or whose [.cmt] cannot be located in
    [_build/default], are skipped. Returns [Ok ()] when the (possibly
    empty) target list builds cleanly. *)
