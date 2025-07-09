(* File using Str module *)
let split_words s = Str.split (Str.regexp " +") s

let contains_pattern s pattern =
  try
    let _ = Str.search_forward (Str.regexp pattern) s 0 in
    true
  with Not_found -> false
