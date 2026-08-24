(* Comparing scalars with the polymorphic operators is fine *)
let same_int (a : int) b = a = b
let same_string s = s = "hello"
let bigger (a : float) b = a > b

(* Transparent containers and tuples of safe types are fine too, however the
   container is spelled - [sorted] infers its list through Stdlib.List *)
let same_pair (a : int * int) b = a = b
let same_path (a : string list) b = a = b
let has_afl o = o = Some "afl"
let sorted xs = List.sort_uniq String.compare xs = [ "x" ]

(* This module's own types: (=) is fine here because the representation is
   visible; expose `equal` in the .mli for other modules to call. *)
type point = { x : int; y : int }
type color = Red | Green | Blue

let equal_point (a : point) b = a = b
let equal_color (a : color) b = a = b

(* Tag checks against a nullary constructor *)
let is_red c = c = Red
let nonempty l = l <> []
let absent o = o = None

(* A polymorphic variant tag is a tag check too. The type here is otherwise
   dangerous - [`Run] wraps a function - but [s = `Idle] short-circuits on the
   tag, so the function payload is never walked. *)
let is_idle (s : [ `Idle | `Run of (unit -> unit) ]) = s = `Idle

(* A constructor wrapping only tag checks is a tag check too: comparing against
   [Ok ()] short-circuits on the constructor tag, so [Res.err] being abstract
   never matters - the error payload is never walked. *)
module Res : sig
  type err

  val run : unit -> (unit, err) result
end = struct
  type err = string

  let run () = Ok ()
end

let succeeded () = Res.run () = Ok ()

(* An operator from another module - like Z.(p > zero) on zarith - is that
   module's own comparison, not Stdlib's, so it is fine even though the
   operand's type is not local. *)
module Money : sig
  type t

  val ( > ) : t -> t -> bool
  val zero : t
end = struct
  type t = int

  let ( > ) = Stdlib.( > )
  let zero = 0
end

let positive (p : Money.t) = Money.(p > zero)

(* A functor applied in this file. [Streams.key] is whatever the argument module
   says its [t] is, and [Counted.t] is an int, so the loop index below is an int
   and comparing it is comparing an int. A module bound here is not a
   compilation unit and has no interface on disk, so this only reads as an int
   through the module type the typechecker recorded for the binding. *)
module Counted = struct
  type t = int

  let compare = Int.compare
end

module Streams = Map.Make (Counted)

let build n =
  let rec go i acc = if i >= n then acc else go (i + 1) (Streams.add i i acc) in
  go 0 Streams.empty

(* The same shape through [Set.Make], with the argument taken straight from the
   stdlib: [Bound.elt] is [Int.t]. *)
module Bound = Set.Make (Int)

let routed set port =
  match if Bound.mem port set then `Port port else `Unbound with
  | `Port p -> p <> port
  | `Unbound -> false
