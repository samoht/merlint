(* Comparing scalars with the polymorphic operators is fine *)
let same_int (a : int) b = a = b
let same_string s = s = "hello"
let bigger (a : float) b = a > b

(* Transparent containers and tuples of safe types are fine too *)
let same_pair (a : int * int) b = a = b
let same_path (a : string list) b = a = b
let has_afl o = o = Some "afl"

(* A transparent record or variant of safe fields is safe to compare *)
type point = { x : int; y : int }
type color = Red | Green | Blue

let same_point (a : point) b = a = b
let same_color (a : color) b = a = b

(* Tag checks against a nullary constructor *)
let is_red c = c = Red
let nonempty l = l <> []
