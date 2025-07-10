open Merlint

let test_get_project_root () =
  (* Create a temporary directory structure *)
  let temp_dir = Filename.temp_file "test_rules" "" in
  Sys.remove temp_dir;
  Unix.mkdir temp_dir 0o755;

  let sub_dir = Filename.concat temp_dir "src" in
  Unix.mkdir sub_dir 0o755;

  (* Create dune-project in temp_dir *)
  let dune_project = Filename.concat temp_dir "dune-project" in
  let oc = open_out dune_project in
  output_string oc "(lang dune 3.0)";
  close_out oc;

  (* Test from subdirectory *)
  let test_file = Filename.concat sub_dir "test.ml" in
  let oc = open_out test_file in
  output_string oc "let x = 1";
  close_out oc;

  let root = Rules.get_project_root test_file in

  (* Clean up *)
  Sys.remove test_file;
  Sys.remove dune_project;
  Unix.rmdir sub_dir;
  Unix.rmdir temp_dir;

  Alcotest.(check string) "project root" temp_dir root

let test_get_project_root_no_dune () =
  (* Test when no dune-project exists *)
  let temp_file = Filename.temp_file "test" ".ml" in
  let root = Rules.get_project_root temp_file in
  Sys.remove temp_file;

  (* Should return the file's directory when no dune-project found *)
  let expected = Filename.dirname temp_file in
  Alcotest.(check string) "defaults to file directory" expected root

let test_default_config () =
  let config = Rules.default_config "/some/path" in
  Alcotest.(check string) "project root" "/some/path" config.project_root;
  (* Just verify we get a valid config *)
  Alcotest.(check bool)
    "has merlint config" true
    (config.merlint_config == Config.default)

let test_analyze_project_empty () =
  let temp_dir = Filename.temp_file "test_rules" "" in
  Sys.remove temp_dir;
  Unix.mkdir temp_dir 0o755;

  let config = Rules.default_config temp_dir in
  let categories = Rules.analyze_project config [] in

  Unix.rmdir temp_dir;

  (* Should have all categories even with no files *)
  Alcotest.(check bool) "has categories" true (List.length categories > 0);

  (* Check that all reports show as passed with no files *)
  List.iter
    (fun (_, reports) ->
      List.iter
        (fun report ->
          if report.Report.file_count > 0 then
            Alcotest.(check bool)
              "empty project passes" true report.Report.passed)
        reports)
    categories

let test_analyze_project_with_file () =
  let temp_dir = Filename.temp_file "test_rules" "" in
  Sys.remove temp_dir;
  Unix.mkdir temp_dir 0o755;

  (* Create a simple ML file *)
  let test_file = Filename.concat temp_dir "test.ml" in
  let oc = open_out test_file in
  output_string oc "let good_name = 42\n";
  close_out oc;

  let config = Rules.default_config temp_dir in
  let categories = Rules.analyze_project config [ test_file ] in

  Sys.remove test_file;
  Unix.rmdir temp_dir;

  (* Should process the file and return results *)
  let all_reports = List.flatten (List.map snd categories) in
  let total_issues = Report.get_all_issues all_reports |> List.length in
  (* Good code should have minimal issues *)
  Alcotest.(check bool) "minimal issues for good code" true (total_issues < 5)

let suite =
  [
    ( "rules",
      [
        Alcotest.test_case "get project root" `Quick test_get_project_root;
        Alcotest.test_case "get project root no dune" `Quick
          test_get_project_root_no_dune;
        Alcotest.test_case "default config" `Quick test_default_config;
        Alcotest.test_case "analyze empty project" `Quick
          test_analyze_project_empty;
        Alcotest.test_case "analyze project with file" `Quick
          test_analyze_project_with_file;
      ] );
  ]
