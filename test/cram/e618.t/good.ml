let example1 = Printf.sprintf "hello"
let example2 = String.length "test"

(* OCaml special identifiers should not trigger E618 *)
let example3 = __LOC__
let example4 = __FILE__
let example5 = __LINE__
let example6 = __MODULE__
let example7 = __POS__