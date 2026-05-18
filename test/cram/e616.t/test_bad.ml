(* Bad examples - using fail (Fmt.str ...) instead of failf *)

module Alcobar = struct
  let fail msg = Alcotest.fail msg
  let failf fmt = Fmt.kstr fail fmt
end

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

(* Multi-line form: regex would have missed this — AST walk catches it. *)
let test_multi_line () =
  let _ =
    Alcotest.fail
      (Fmt.str "Multi-line %s call" "fail")
  in
  ()

let test_kstr () =
  let _ = Fmt.kstr Alcobar.fail "Formatted %s failure" "test" in
  ()
