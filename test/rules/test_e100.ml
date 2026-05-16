let test_does_not_force_outline () =
  let outline_called = ref 0 in
  let ctx =
    Merlint.Context.file ~filename:"bad.ml" ~config:Merlint.Config.default
      ~project_root:"."
      ~load_content:(fun () -> "let x = Obj.magic 1\n")
      ~outline:(fun () ->
        incr outline_called;
        Error "outline should not be forced")
  in
  let issues = Merlint.Rule.Run.file Merlint.E100.rule ctx in
  Alcotest.(check int) "reports Obj.magic" 1 (List.length issues);
  Alcotest.(check int) "outline not forced" 0 !outline_called

let fixture_suite =
  Test_rules_harness.Test_harness.fixture_suite Merlint.E100.rule

let suite =
  let name, tests = fixture_suite in
  ( name,
    tests
    @ [
        Alcotest.test_case "does not force outline" `Quick
          test_does_not_force_outline;
      ] )
