(** Good example - encapsulated state *)

(** Initialize the counter *)
val init : unit -> unit

(** Increment the counter and return new value *)
val increment : unit -> int

(** Get current counter value *)
val get_count : unit -> int

(** Cache operations - state is encapsulated *)
val cache_get : int -> int option
val cache_set : int -> int -> unit
val cache_clear : unit -> unit