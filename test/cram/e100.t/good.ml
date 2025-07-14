(* Use proper type conversions *)
let int_of_string_opt s =
  try Some (int_of_string s) with _ -> None

(* Or use variant types *)
type value = Int of int | String of string
let to_int = function Int i -> Some i | _ -> None