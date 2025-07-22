(** Simple profiling module for measuring execution times. *)

type t
(** Profiling state. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] have equal timings. Uses polymorphic equality. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. Uses polymorphic comparison. *)

val pp : t Fmt.t
(** [pp fmt t] pretty-prints the profiling state. *)

val create : unit -> t
(** [create ()] creates a new profiling state. *)

val reset_state : t -> unit
(** [reset_state t] clears all timings in the state. *)

val print_summary : t -> unit
(** [print_summary t] prints timing summary from the given state. *)

val print_file_summary : t -> unit
(** [print_file_summary t] prints per-file breakdown from the given state. *)
