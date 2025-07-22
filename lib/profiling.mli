(** Simple profiling module for measuring execution times. *)

type t
(** Profiling state. *)

val create : unit -> t
(** [create ()] creates a new profiling state. *)

val reset_state : t -> unit
(** [reset_state t] clears all timings in the state. *)

val print_summary_from_state : t -> unit
(** [print_summary_from_state t] prints timing summary from the given state. *)

val print_per_file_summary_from_state : t -> unit
(** [print_per_file_summary_from_state t] prints per-file breakdown from the given state. *)
