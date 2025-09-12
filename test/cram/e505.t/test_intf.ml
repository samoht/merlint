(** Test interface definition file - should not require .mli *)

type t = int

val create : unit -> t
val get : t -> int