(* Good examples - using failf directly *)

let test_parse () =
  let _input = "invalid" in
  let _ = Alcotest.failf "Parse error: %s" "error" in
  ()

let test_validation () =
  let data = 42 in
  if data < 0 then
    let _ = Alcotest.failf "Invalid data: %d" data in
    ()
  else
    ()

let test_connection () =
  let code = 500 in
  let _ = Alcotest.failf "Connection failed with code %d" code in
  ()

let test_complex_format () =
  let items = [1; 2; 3] in
  let _ = Alcotest.failf "Expected items: %s" "test" in
  ignore items