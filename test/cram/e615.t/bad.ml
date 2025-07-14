(* test/test.ml *)
let () = Alcotest.run "all" [Test_user.suite] 
(* Missing Test_parser.suite *)