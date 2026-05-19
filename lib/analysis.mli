(** Project-wide pre-computed per-file facts. Built once at engine start, in
    parallel; rules read from it instead of forcing typedtree walks and deriving
    the same facts repeatedly. *)

type t

val build :
  domain_mgr:_ Eio.Domain_manager.t option ->
  view_of:(string -> File_view.t) ->
  string list ->
  t
(** [build ~domain_mgr ~view_of files] forces a typedtree analysis for every
    file in [files] and stores the derived facts. When [domain_mgr] is given,
    files are processed in parallel; otherwise sequentially. *)

val suite_callers : t -> string -> Suite.callers option
(** [suite_callers t filename] is the precomputed [Suite.callers] for the given
    file's typedtree, or [None] when the file is absent / typedtree unavailable.
*)
