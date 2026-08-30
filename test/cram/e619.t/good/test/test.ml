(* Runner naming every suite the cases library defines, including the one
   declared as a list. *)
let () =
  Alcotest.run "all" (Test_list.suite @ [ Test_used.suite; Test_unused.suite ])
