type t = int

(* Should be [pp] — type signature is [Format.formatter -> t -> unit] *)
let print fmt v = Format.fprintf fmt "%d" v

(* Should be [pp_widget] — value type is [widget] *)
type widget = { x : int }
let dump_widget fmt w = Format.fprintf fmt "%d" w.x
