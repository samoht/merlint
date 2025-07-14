(* test/test.ml *)
let () = Alcotest.run "all" [
  Test_user.suite;
  Test_parser.suite
]