(* test/test.ml *)
module Test_user = struct
  let suite = ("user", [])
end

module Test_parser = struct
  let suite = ("parser", [])
end

let () = Alcotest.run "all" [Test_user.suite; Test_parser.suite]