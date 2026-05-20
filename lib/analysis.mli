(** Project-wide pre-computed per-file facts. Built once at engine start, in
    parallel; rules read from it instead of forcing typedtree walks and deriving
    the same facts repeatedly. *)

type t

val pp : t Fmt.t
(** [pp] formats the filenames with precomputed analysis facts. *)

val build :
  ?pool:Eio.Executor_pool.t ->
  view_of:(string -> File_view.t) ->
  string list ->
  t
(** [build ?pool ~view_of files] forces a typedtree analysis for every file in
    [files] and stores the derived facts. When [pool] is given, files are
    processed in parallel on the supplied [Eio.Executor_pool]; otherwise
    sequentially. *)

val suite_callers : t -> string -> Suite.callers option
(** [suite_callers t filename] is the precomputed [Suite.callers] for the given
    file's typedtree, or [None] when the file is absent / typedtree unavailable.
*)
