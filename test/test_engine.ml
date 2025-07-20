open Merlint

let test_get_project_root () =
  (* Test finding project root *)
  let cwd = Sys.getcwd () in
  let project_root = Engine.get_project_root cwd in
  (* Should find a dune-project file somewhere up the tree *)
  Alcotest.(check bool)
    "found project root" true
    (Sys.file_exists (Filename.concat project_root "dune-project"))

let test_run_empty_filter () =
  (* Test running with all rules disabled using "none" keyword *)
  match Filter.parse "none" with
  | Error msg ->
      Alcotest.fail (Printf.sprintf "Failed to create filter: %s" msg)
  | Ok filter ->
      let dune_describe = Dune.describe (Fpath.v ".") in
      let results = Engine.run ~filter ~dune_describe "." in
      Alcotest.(check int)
        "no results with all rules disabled" 0 (List.length results)

let suite =
  [
    ( "engine",
      [
        Alcotest.test_case "get project root" `Quick test_get_project_root;
        Alcotest.test_case "run with empty filter" `Quick test_run_empty_filter;
      ] );
  ]
