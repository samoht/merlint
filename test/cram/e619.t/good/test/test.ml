(* Runner naming every suite the cases library defines. *)
let () = Alcotest.run "all" [ Test_used.suite; Test_unused.suite ]
