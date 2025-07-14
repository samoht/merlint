(** Simple profiling module for measuring execution times *)

type timing = { name : string; duration : float }

val time : string -> (unit -> 'a) -> 'a
(** [time name f] executes function [f] and records its execution time under
    [name] *)

val reset : unit -> unit
(** [reset ()] clears all recorded timings *)

val get_timings : unit -> timing list
(** [get_timings ()] returns all recorded timings in chronological order *)

val print_summary : unit -> unit
(** [print_summary ()] prints a formatted summary of all timings to stdout *)

val print_per_file_summary : unit -> unit
(** [print_per_file_summary ()] prints a per-file breakdown of timings to stdout
*)
