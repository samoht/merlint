let dummy_index = lazy (failwith "Project_index not built in E600 tests")

let test_does_not_force_outline () =
  let outline_called = ref 0 in
  let file_view filename =
    Merlint.File_view.v ~filename
      ~load_content:(fun () ->
        {|let tests = [ Alcotest.test_case "x" `Quick (fun () -> ()) ]
let () = Alcotest.run "suite" tests
|})
      ~outline:(fun () ->
        incr outline_called;
        Error "outline should not be forced")
      ()
  in
  let ctx =
    Merlint.Context.project ~config:Merlint.Config.default ~project_root:"."
      ~all_files:[ "test.ml" ]
      ~dune_describe:(Merlint.Dune_describe.describe (Fpath.v "."))
      ~index:dummy_index ~file_view ()
  in
  let issues = Merlint.Rule.Run.project Merlint.E600.rule ctx in
  Alcotest.(check bool) "reports inline runner tests" true (issues <> []);
  Alcotest.(check int) "outline not forced" 0 !outline_called

let fixture_suite =
  Test_rules_harness.Test_harness.fixture_suite Merlint.E600.rule

let suite =
  let name, tests = fixture_suite in
  ( name,
    tests
    @ [
        Alcotest.test_case "does not force outline" `Quick
          test_does_not_force_outline;
      ] )
