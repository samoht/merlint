(* test.ml - main test executable *)
module Test_user = struct
  let suite = ("user", [])
end

let () = Alcotest.run "Test suite description" [Test_user.suite]