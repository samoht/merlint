(* Good test file that exports suite *)

let test_example () = ()

let suite : (string * unit Alcotest.test_case list) list =
  [
    ("example", [ Alcotest.test_case "test" `Quick test_example ]);
  ]

let () = Alcotest.run "Good tests" suite