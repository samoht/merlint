(* Good examples - using failf directly *)

open Alcotest

let test_parse () =
  let input = "invalid" in
  match parse_something input with
  | Error e -> Alcotest.failf "Parse error: %s" e
  | Ok _ -> ()

let test_validation () =
  let data = { field = "test"; value = 42 } in
  if not (is_valid data) then
    failf "Invalid data: %a" pp_data data
  else
    ()

let test_connection () =
  match connect_to_server () with
  | Error code -> 
      (* Using qualified form *)
      Alcotest.failf "Connection failed with code %d" code
  | Ok conn -> 
      close_connection conn

let test_complex_format () =
  let items = [1; 2; 3] in
  let expected = [1; 2; 3; 4] in
  if items <> expected then
    failf "Expected %a but got %a" 
      (Fmt.list ~sep:(Fmt.any ", ") Fmt.int) expected
      (Fmt.list ~sep:(Fmt.any ", ") Fmt.int) items

(* Helper functions - these would be defined elsewhere *)
let parse_something _ = Error "not implemented"
let is_valid _ = false  
let pp_data = Fmt.any "data"
let connect_to_server () = Error 500
let close_connection _ = ()