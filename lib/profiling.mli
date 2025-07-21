(** Simple profiling module for measuring execution times. *)

val reset : unit -> unit
(** [reset] clears all timings. *)

val print_summary : unit -> unit
(** [print_summary] prints timing summary. *)

val print_per_file_summary : unit -> unit
(** [print_per_file_summary] prints per-file breakdown. *)
