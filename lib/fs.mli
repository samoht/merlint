(** Thin counted wrappers around [Sys] / [Stdlib] filesystem primitives. *)

type stats = {
  readdirs : int;
  is_directory_checks : int;
  file_exists_checks : int;
  file_opens : int;
}
(** Snapshot of cumulative I/O counts since the last {!reset_stats}. *)

val stats : unit -> stats
(** [stats ()] snapshots the current counters. *)

val reset_stats : unit -> unit
(** [reset_stats ()] zeroes every counter. Call once at the start of a run. *)

val readdir : string -> string array
(** [readdir dir] is [Sys.readdir dir] with the call counted. *)

val readdir_or_empty : string -> string list
(** [readdir_or_empty dir] is [readdir dir |> Array.to_list], returning the
    empty list on [Sys_error _]. *)

val is_directory : string -> bool
(** [is_directory p] is [Sys.is_directory p] with the call counted; returns
    [false] when [p] doesn't exist or isn't accessible. *)

val file_exists : string -> bool
(** [file_exists p] is [Sys.file_exists p] with the call counted. *)

val with_open_in : string -> (in_channel -> 'a) -> 'a
(** [with_open_in p f] opens [p] for text reading, runs [f], closes the channel
    on the way out. The open is counted. *)

val with_open_in_bin : string -> (in_channel -> 'a) -> 'a
(** [with_open_in_bin p f] is {!with_open_in} for binary mode. *)

val read_file : string -> string
(** [read_file p] slurps the file as a string via {!with_open_in}. Raises
    [Sys_error] if the file can't be opened. *)

val parallel_map :
  _ Eio.Domain_manager.t ->
  ?domain_count:int ->
  'a list ->
  ('a -> 'b) ->
  'b list
(** [parallel_map dm ?domain_count xs f] applies [f] to every [xs] element on an
    [Eio.Executor_pool] backed by [dm]. Results are returned in [xs] order.
    Caller must guarantee that [f] is safe to run concurrently across domains --
    merlint's project rules walk typedtree records with no global mutable state,
    which qualifies; rules that mutate shared accumulators must serialise on
    their own. [domain_count] defaults to 4. *)
