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
