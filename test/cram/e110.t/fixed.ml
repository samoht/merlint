let used_function x = x + 1

let () = print_int (used_function 5)

let complete_match = function
  | Some x -> x
  | None -> 0

type t = { field : int; another : string }