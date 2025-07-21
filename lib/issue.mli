(** Issue types and formatting. *)

type 'a t
(** Issue with a specific payload type. *)

val v : ?loc:Location.t -> 'a -> 'a t
(** [v ?loc payload] creates a new issue. *)

val pp : 'a Fmt.t -> 'a t Fmt.t
(** [pp payload_pp] creates a pretty-printer. *)

val compare : 'a t -> 'a t -> int
(** [compare a b] compares issues. *)

val location : 'a t -> Location.t option
(** [location issue] returns the location of an issue. *)
