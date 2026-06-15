(* Use a typed encoder and decoder instead of Marshal *)
let to_string i = string_of_int i
let of_string s = int_of_string_opt s
