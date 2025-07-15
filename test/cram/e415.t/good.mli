type user = { id: int; name: string }
val equal : user -> user -> bool
val compare : user -> user -> int
val pp : Format.formatter -> user -> unit