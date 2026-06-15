(* An abstract type hides its representation *)
module Id : sig
  type t

  val v : int -> t
end = struct
  type t = int

  let v x = x
end

type handler = { name : string; run : unit -> unit }

(* (=) on an abstract type reaches through the abstraction boundary *)
let same_id (a : Id.t) b = a = b

(* compare on an abstract type *)
let order_id (a : Id.t) b = compare a b

(* (=) on a function value: also raises Invalid_argument at runtime *)
let same_fn (a : int -> int) b = a = b

(* (=) on a record that contains a function *)
let same_handler (a : handler) b = a = b

(* Hashtbl.hash on a record that contains a function *)
let key (h : handler) = Hashtbl.hash h
