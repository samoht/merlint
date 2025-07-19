type t = { id: int; name: string }
val equal : t -> t -> bool
val compare : t -> t -> int
val pp : Format.formatter -> t -> unit