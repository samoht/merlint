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

(** User-defined [array] type shadowing Stdlib's - not a mutable primitive,
    must not be flagged. *)
type 'a array = Nil | Cons of 'a

val users : int array

(** Functions that take or return [Stdlib.array] / [Stdlib.ref] are NOT
    exposed mutable state — the array/ref is a transient parameter or
    return value, not a module-level singleton. Only top-level non-function
    [val] declarations of array/ref type are flagged. *)
val process : float Stdlib.array -> int Stdlib.array -> int

val build : int -> float Stdlib.array

val update_counter : int Stdlib.ref -> unit