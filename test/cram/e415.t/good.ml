type t = { id: int; name: string }
let pp fmt t = Format.fprintf fmt "{id=%d; name=%S}" t.id t.name