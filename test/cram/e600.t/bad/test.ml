(* test.ml - main test executable *)
(* BAD: Creating our own tests instead of using test_user.suite *)
let tests = []
let () = Alcotest.run "test_user" [("user", tests)]