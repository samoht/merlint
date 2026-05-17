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

(** Functions that take or return array/ref values are NOT
    exposed mutable state — the array/ref is a transient parameter or
    return value, not a module-level singleton. Only top-level non-function
    [val] declarations of array/ref type are flagged. *)
val process : float array -> int array -> int

val build : int -> float array

val update_counter : int ref -> unit
