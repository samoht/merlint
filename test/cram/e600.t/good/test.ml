(* test.ml - main test executable *)
(* GOOD: Using test_user.suite exported by test_user.ml *)
module Test_user = struct
  let suite = ("user", [])
end

let () = Alcotest.run "Test suite description" [Test_user.suite]