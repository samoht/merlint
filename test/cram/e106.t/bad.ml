(* Id.t is abstract here: another module's type, so it must be compared
   through Id.equal, not by walking its hidden representation. *)
module Id : sig
  type t

  val v : int -> t
end = struct
  type t = int

  let v x = x
end

(* (=) on another module's type *)
let same_id (a : Id.t) b = a = b

(* compare on another module's type *)
let order_id (a : Id.t) b = compare a b

(* Hashtbl.hash on another module's type *)
let key (a : Id.t) = Hashtbl.hash a

(* (=) on an abstract type from another library (Re.t is a compiled regex) *)
let same_re (a : Re.t) b = a = b

(* (=) on a function value: this also raises Invalid_argument at runtime *)
let same_fn (a : int -> int) b = a = b

(* Stdlib (>) on another module's type: should use Id.compare *)
let gt (a : Id.t) b = a > b

(* Comparing two result VALUES whose error type is abstract: when both are
   Error the walk reaches the hidden Id.t, so this must go through its own
   equal - unlike a tag check against [Ok ()], which never walks the error. *)
let same_res (a : (unit, Id.t) result) b = a = b
