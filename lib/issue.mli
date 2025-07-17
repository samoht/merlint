(** Issue types and formatting *)

type 'a t
(** An issue with a specific payload type *)

val v : ?loc:Location.t -> 'a -> 'a t
(** Create a new issue *)

val disabled : unit -> 'a t

val pp : 'a Fmt.t -> 'a t Fmt.t
(** Pretty-printer for issues *)

val compare : 'a t -> 'a t -> int
(** Compare issues for sorting *)

val location : 'a t -> Location.t option
