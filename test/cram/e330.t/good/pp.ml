(* Pretty-printing module - pp function should be allowed *)

let pp fmt x = Format.fprintf fmt "%d" x

(* Other functions don't need the pp prefix *)
let to_string x = string_of_int x