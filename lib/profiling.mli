(** Simple profiling module for measuring execution times *)

val reset : unit -> unit
(** [reset ()] clears all recorded timings *)

val print_summary : unit -> unit
(** [print_summary ()] prints a formatted summary of all timings to stdout *)

val print_per_file_summary : unit -> unit
(** [print_per_file_summary ()] prints a per-file breakdown of timings to stdout
*)
