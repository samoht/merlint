(* test.ml - main test executable *)
let tests = []
let () = Alcotest.run "test_user" [("user", tests)]