(* test/test.ml *)
module Test_user = struct
  let suite = ("user", [])
end
let () = Alcotest.run "all" [Test_user.suite] 
(* Missing Test_parser.suite *)