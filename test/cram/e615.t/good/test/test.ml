(* Main test runner - includes all test modules *)
module Test_user = struct
  let suite = ("user", [])
end

let () = Alcotest.run "all" [Test_user.suite; Test_parser.suite]