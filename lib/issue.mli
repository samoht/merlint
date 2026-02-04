(** Issue types and formatting. *)

type 'a t
(** Issue with a specific payload type. *)

val v : ?loc:Location.t -> ?severity:int -> 'a -> 'a t
(** [v ?loc ?severity payload] creates a new issue. Severity defaults to 0;
    higher values indicate more severe issues. *)

val pp : 'a Fmt.t -> 'a t Fmt.t
(** [pp payload_pp] creates a pretty-printer. *)

val compare : 'a t -> 'a t -> int
(** [compare a b] compares issues by severity (descending), then by location. *)

val location : 'a t -> Location.t option
(** [location issue] returns the location of an issue. *)

val severity : 'a t -> int
(** [severity issue] returns the severity of an issue. *)
