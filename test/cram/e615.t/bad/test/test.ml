(* Main test runner - missing Test_parser.suite *)
module Test_user = struct
  let suite = ("user", [])
end

let () = Alcotest.run "all" [Test_user.suite]