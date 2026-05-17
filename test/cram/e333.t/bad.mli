val int_to_string : int -> string
val bytes_to_hex : bytes -> string
val path_to_uri : string -> string
val value_from_string : string -> int
val bytes_from_hex : string -> bytes

type t = int

val int_of_t : t -> int
val t_of_int : int -> t
val to_pair : string -> string * string
