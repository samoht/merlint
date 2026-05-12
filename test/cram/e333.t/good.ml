(* Good examples: [<dst>_of_<src>] form, matching stdlib's [int_of_string]. *)

let string_of_int' n = string_of_int n

let hex_of_bytes (b : bytes) =
  let buf = Buffer.create (Bytes.length b * 2) in
  Bytes.iter (fun c -> Buffer.add_string buf (Printf.sprintf "%02x" (Char.code c))) b;
  Buffer.contents buf

let uri_of_path p = "file://" ^ p

let value_of_string s = int_of_string s
let bytes_of_hex h = Bytes.of_string h

(* These have [_to_]/[_from_] in the name but are NOT conversions by type:
   the type-shape check excludes multi-arrow and unit-return functions. *)

let add_to_set s x = x :: s
(* val add_to_set : 'a list -> 'a -> 'a list — two arrows, not flagged. *)

let print_to_buffer buf x = Buffer.add_string buf x
(* val print_to_buffer : Buffer.t -> string -> unit — unit return, not flagged. *)

let recover_from_error e = ignore e
(* val recover_from_error : 'a -> unit — unit return, not flagged. *)

(* Inside a module whose type is [t]: the canonical conversion names are
   [to_<X>] (source implicit [t]) and [of_<X>] (destination implicit [t]). *)

type t = int

let to_int (x : t) = x
let of_int n : t = n

(* When [type t = X] is a transparent alias and the [.ml] omits a type
   annotation, Merlin infers the body as [X -> Y]. The rule still recognises
   the canonical [to_<Y>] / [of_<X>] forms by tracking the alias declared at
   the top of the file: [Tid.to_string] below is [string -> string] after
   alias resolution, but [type t = string] makes that legitimate. *)

module Tid = struct
  type t = string
  let to_string s = s
  let of_string s : t = s
end

(* Multiple sibling modules, each with their own [type t = X]. The alias
   tracking is scoped per module: [Inner.to_int : t -> int] resolves to
   [int -> int] (where [t = int] in Inner), and [Outer.to_string : t ->
   string] resolves to [string -> string] (where [t = string] in Outer).
   Neither cross-contaminates the other. *)

module Inner = struct
  type t = int
  let to_int t = t
  let of_int n : t = n
end

module Outer = struct
  type t = string
  let to_string t = t
  let of_string s : t = s
end

(* Aliases on parameterised types: [type t = entry list] should accept
   both [list] and [entry] as legitimate source-type names. *)

type entry = { name : string }
type tree = entry list

(* A function on the parameterised alias is accepted as [t -> ...]
   even when Merlin's inferred type uses the unfolded [entry list]. *)
module Tree = struct
  type t = tree
  let to_entries (t : t) = t
end
