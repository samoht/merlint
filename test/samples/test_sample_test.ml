(* Test file that exports module name instead of suite *)

let tests = [
  Alcotest.test_case "test1" `Quick (fun () -> ());
  Alcotest.test_case "test2" `Quick (fun () -> ());
]

let () = 
  Alcotest.run "test_sample" [
    ("basic", tests);
  ]