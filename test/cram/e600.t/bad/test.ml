(* test.ml - main test executable that defines its own tests instead of using test suites *)
let tests = 
  [ Alcotest.test_case "sample" `Quick (fun () -> ()) ]

let () = Alcotest.run "test" [("main", tests)]