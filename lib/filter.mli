(** Rule filtering for merlint. *)

type t
(** Rule filter configuration. *)

val parse : string -> (t, string) result
(** [parse spec] parses rule specification using simple format without quotes.
*)

val is_enabled_by_code : t -> string -> bool
(** [is_enabled_by_code filter code] checks if a specific error code is enabled.
*)
