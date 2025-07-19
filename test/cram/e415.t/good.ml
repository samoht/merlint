type t = { id: int; name: string }
let equal a b = a.id = b.id && a.name = b.name
let compare a b = 
  let c = Int.compare a.id b.id in
  if c = 0 then String.compare a.name b.name else c
let pp fmt t = Format.fprintf fmt "{id=%d; name=%S}" t.id t.name