(* Test file for E105 Catch-all exception detection *)

(* Should NOT be flagged - underscore in normal pattern matching *)
let process_option = function
  | Some x -> x
  | None -> 0

(* Should NOT be flagged - underscore in let binding *)
let helper x =
  let _ = print_endline "debug" in
  x + 1

(* Should NOT be flagged - underscore in function parameter *)
let ignore_second x _ = x

(* Should NOT be flagged - underscore in match expression *)
let check_value = function
  | 0 -> "zero"
  | _ -> "other"

(* SHOULD be flagged - catch-all exception handler *)
let risky_function () =
  try 
    failwith "boom"
  with _ -> "error"

(* SHOULD be flagged - catch-all with underscore variable *)
let another_risky () =
  try
    List.hd []
  with _ -> None

(* Should NOT be flagged - specific exception handling *)
let safe_function () =
  try
    List.hd []
  with 
  | Failure msg -> None
  | Invalid_argument _ -> None

(* Should NOT be flagged - catching specific then re-raising *)
let better_handler () =
  try
    risky_operation ()
  with
  | Known_error -> handle_known ()
  | exn -> 
      log_error exn;
      raise exn