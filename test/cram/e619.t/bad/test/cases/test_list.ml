(* A module whose [suite] is a list of suites rather than one (name, cases)
   pair, as ocaml-hash/test/backend and ocaml-crypto/test/backend write it. *)
let test_first () = Alcotest.(check bool) "first" true true
let test_second () = Alcotest.(check bool) "second" true true

let suite =
  [
    ("first", [ Alcotest.test_case "first" `Quick test_first ]);
    ("second", [ Alcotest.test_case "second" `Quick test_second ]);
  ]
