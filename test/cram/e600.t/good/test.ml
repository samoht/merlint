(* test.ml - main test executable that properly uses test suites *)
let () = Alcotest.run "test" [Test_user.suite]