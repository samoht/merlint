type t
val parse : string -> t

(** Documentation after is also acceptable *)
val format : t -> string

val missing_documentation : int -> int