let fixture_suite =
  Test_rules_harness.Test_harness.fixture_suite Merlint.E300.rule

let test_reports_variant_definition_once () =
  let ctx =
    Merlint.Context.file ~filename:"variant.ml" ~config:Merlint.Config.default
      ~project_root:"."
      ~load_content:(fun () ->
        {|
type t = BadCase | Good_case

let x = BadCase

let y =
  match x with
  | BadCase -> Good_case
  | Good_case -> BadCase
|})
      ~outline:(fun () -> Error "outline should not be forced")
  in
  let issues = Merlint.Rule.Run.file Merlint.E300.rule ctx in
  Alcotest.(check int) "one issue for definition only" 1 (List.length issues)

let suite =
  let name, tests = fixture_suite in
  ( name,
    tests
    @ [
        Alcotest.test_case "reports variant definition once" `Quick
          test_reports_variant_definition_once;
      ] )
