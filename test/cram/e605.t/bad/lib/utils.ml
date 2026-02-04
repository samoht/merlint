(* Utility functions for myproject *)

let string_of_list to_string lst =
  "[" ^ String.concat "; " (List.map to_string lst) ^ "]"

let time_it f =
  let start = Sys.time () in
  let result = f () in
  let elapsed = Sys.time () -. start in
  (result, elapsed)

let option_map f = function
  | None -> None
  | Some x -> Some (f x)