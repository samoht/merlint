(* Bad examples - using fail (Fmt.str ...) instead of failf *)

let test_parse () =
  let _input = "invalid" in
  let _ = Alcotest.fail (Fmt.str "Parse error: %s" "error") in
  ()

let test_validation () =
  let data = 42 in
  if data < 0 then
    let _ = Alcotest.fail (Fmt.str "Invalid data: %d" data) in
    ()
  else
    ()

let test_connection () =
  let code = 500 in
  let _ = Alcotest.fail (Fmt.str "Connection failed with code %d" code) in
  ()

let test_complex_format () =
  let items = [1; 2; 3] in
  let _ = Alcotest.fail (Fmt.str "Expected items: %s" "test") in
  ignore items