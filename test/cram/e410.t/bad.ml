type t = string
let parse s = s
let ( @> ) x y = x ^ y
let ( <@ ) x y = y ^ x
let border_current = "border-current"
let default = "default"
let create ?(debug = false) ~name t =
  if debug then name ^ t else t
