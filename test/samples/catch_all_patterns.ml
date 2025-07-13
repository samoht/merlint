(* Test file for catch-all pattern detection *)

(* Should trigger E105: catch-all exception handler *)
let safe_divide x y =
  try x / y with
  | _ -> 0  (* This should be flagged *)

(* Should trigger E105: another catch-all exception *)
let read_file filename =
  try
    let ic = open_in filename in
    let content = input_line ic in
    close_in ic;
    Some content
  with _ -> None  (* This should be flagged *)

(* Should NOT trigger: underscore in pattern matching *)
let process_option = function
  | Some x -> x
  | None -> 0

(* Should NOT trigger: underscore in let binding *)
let _ = print_endline "Hello"

(* Should NOT trigger: underscore in function parameter *)
let ignore_first _ y = y

(* Should NOT trigger: underscore in tuple destructuring *)
let get_second (_, y) = y

(* Should trigger E105: catch-all in nested try *)
let complex_operation () =
  match Some 42 with
  | Some x -> (
      try x / 0 with
      | _ -> -1  (* This should be flagged *)
    )
  | None -> 0