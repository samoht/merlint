type t = int

let pp fmt v = Format.fprintf fmt "%d" v

type widget = { x : int }
let pp_widget fmt w = Format.fprintf fmt "%d" w.x
