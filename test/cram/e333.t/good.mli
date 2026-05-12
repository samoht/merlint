(* Intra-public alias: the [.mli] is the place where the convention
   actually matters (it's what callers see). The rule must respect
   [type t = X] aliases in signatures too. *)

type t = int

val to_int : t -> int
val of_int : int -> t

(* Nested signature with its own [type t]. *)
module Tid : sig
  type t = string
  val to_string : t -> string
  val of_string : string -> t
end

(* Parameterised alias: [list] in the source should be accepted. *)
type entry = { name : string }
type tree = entry list

module Tree : sig
  type t = tree
  val to_entries : t -> entry list
end
