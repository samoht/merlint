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

(* Handle keeps its representation to itself, so the table it keys has an
   abstract key and a record carrying that key is as hidden as the key is: the
   walk reaches Handle's contents through the field. Same locally-applied
   functor shape as good.ml's Streams, and the opposite verdict - reading the
   local module's own signature is what tells the two apart. *)
module Handle : sig
  type t

  val v : int -> t
  val compare : t -> t -> int
end = struct
  type t = int

  let v x = x
  let compare = Int.compare
end

module Table = Map.Make (Handle)

module Entry : sig
  type t = { key : Table.key; hits : int }
end = struct
  type t = { key : Table.key; hits : int }
end

let same_entry (a : Entry.t) b = a = b

(* The same through a plain abstract type rather than a functor: an address
   promises compare alone, so a message carrying one needs its own equal. *)
module Addr : sig
  type t

  val v : string -> t
end = struct
  type t = string

  let v x = x
end

module Msg : sig
  type t = { src : Addr.t; ttl : int }
end = struct
  type t = { src : Addr.t; ttl : int }
end

let same_msg (a : Msg.t) b = a = b
