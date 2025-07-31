(** Simple profiling module for measuring execution times. *)

(** Type of operation being timed. *)
type operation_type =
  | Merlin of string  (** Merlin analysis of a file *)
  | File_rule of { rule_code : string; filename : string }
      (** File-scoped rule *)
  | Project_rule of string  (** Project-scoped rule code *)
  | Other of string  (** Other operations *)

type timing = { operation : operation_type; duration : float }
(** A single timing record with operation type and duration in seconds. *)

type t
(** Profiling state. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] have equal timings. Uses polymorphic
    equality. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. Uses
    polymorphic comparison. *)

val pp : t Fmt.t
(** [pp fmt t] pretty-prints the profiling state. *)

val v : unit -> t
(** [v ()] creates a new profiling state. *)

val add_timing : t -> timing -> unit
(** [add_timing t timing] adds a timing record to the profiling state. *)

val reset_state : t -> unit
(** [reset_state t] clears all timings in the state. *)

val print_summary : ?width:int -> t -> unit
(** [print_summary ?width t] prints timing summary from the given state. If
    [width] is provided, formats output to fit within that width. *)

val print_file_summary : ?width:int -> t -> unit
(** [print_file_summary ?width t] prints per-file breakdown from the given
    state. If [width] is provided, formats output to fit within that width. *)

val print_rule_summary : ?width:int -> t -> unit
(** [print_rule_summary ?width t] prints per-rule breakdown from the given
    state. If [width] is provided, formats output to fit within that width. *)
