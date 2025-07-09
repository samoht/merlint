open Merlint

(* Test the complete rules system with real OCaml code *)

let test_analyze_simple_file () =
  (* Create a temporary file with issues *)
  let temp_file = Filename.temp_file "merlint_test" ".ml" in
  let oc = open_out temp_file in
  output_string oc "let test_obj_magic x = Obj.magic x\n";
  close_out oc;

  let config = Config.default in
  let project_root = Merlint.Rules.get_project_root temp_file in
  let rules_config = Merlint.Rules.{ merlint_config = config; project_root } in
  let category_reports =
    Merlint.Rules.analyze_project rules_config [ temp_file ]
  in
  let issues =
    List.fold_left
      (fun acc (_category_name, reports) ->
        List.fold_left
          (fun acc report -> report.Merlint.Report.issues @ acc)
          acc reports)
      [] category_reports
  in
  if true then (
    let has_obj_magic =
      List.exists (function Issue.No_obj_magic _ -> true | _ -> false) issues
    in
    Alcotest.check Alcotest.bool "detects Obj.magic" true has_obj_magic;
    Sys.remove temp_file)

let no_issues_clean_code () =
  (* Create a temporary file without issues *)
  let temp_file = Filename.temp_file "merlint_test" ".ml" in
  let oc = open_out temp_file in
  output_string oc "let add x y = x + y\n";
  close_out oc;

  let config = Config.default in
  let project_root = Merlint.Rules.get_project_root temp_file in
  let rules_config = Merlint.Rules.{ merlint_config = config; project_root } in
  let category_reports =
    Merlint.Rules.analyze_project rules_config [ temp_file ]
  in
  let issues =
    List.fold_left
      (fun acc (_category_name, reports) ->
        List.fold_left
          (fun acc report -> report.Merlint.Report.issues @ acc)
          acc reports)
      [] category_reports
  in
  let issue_count = List.length issues in
  (* Should only have format issues (missing .mli, .ocamlformat) *)
  Alcotest.check Alcotest.bool "has few issues" (issue_count <= 2) true;
  Sys.remove temp_file

let tests =
  [
    Alcotest.test_case "analyze_with_issues" `Quick test_analyze_simple_file;
    Alcotest.test_case "analyze_clean_code" `Quick no_issues_clean_code;
  ]

let suite = [ ("rules_integration", tests) ]
