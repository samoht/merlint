(* PPX-generated code should be ignored *)
let () =
  let __ppx_inline_test_1 = true in
  if __ppx_inline_test_1 then
    print_endline "PPX test passed"

(* Regular underscore-prefixed binding should still be flagged *)
let () =
  let _regular_underscore = 42 in
  print_int _regular_underscore