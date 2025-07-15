type t = { name: string; id: int }
let create name id = { name; id }
let name t = t.name