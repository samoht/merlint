type t = int

(* Bad: [print] is a printer-typed value but doesn't start with [pp]/[pp_]
   or [dump]/[dump_]. *)
let print fmt v = Format.fprintf fmt "%d" v

(* Good: [dump_widget] is accepted as an in-tree convention for human-readable
   diagnostic dumps. *)
type widget = { x : int }

let dump_widget fmt w = Format.fprintf fmt "%d" w.x
