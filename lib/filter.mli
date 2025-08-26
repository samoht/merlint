(** Rule filtering for merlint. *)

type t
(** Rule filter configuration. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are equal filters. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for the filter configuration. *)

val parse : string -> (t, string) result
(** [parse spec] parses rule specification using simple format without quotes.
*)

val is_enabled_by_code : t -> string -> bool
(** [is_enabled_by_code filter code] checks if a specific error code is enabled.
*)
