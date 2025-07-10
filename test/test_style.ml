open Merlint

let create_temp_file content =
  let temp_file = Filename.temp_file "test_style" ".ml" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;
  temp_file

let test_no_style_issues () =
  let content = "let safe_function x = x + 1\nlet y = safe_function 42" in
  let temp_file = create_temp_file content in

  match Merlin.get_parsetree temp_file with
  | Ok parsetree_result ->
      let issues = Style.check ~filename:temp_file parsetree_result in
      Sys.remove temp_file;
      Alcotest.(check int) "no style issues" 0 (List.length issues)
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let test_obj_magic_usage () =
  let content = "let dangerous = Obj.magic 42" in
  let temp_file = create_temp_file content in

  match Merlin.get_parsetree temp_file with
  | Ok parsetree_result -> (
      let issues = Style.check ~filename:temp_file parsetree_result in
      Sys.remove temp_file;
      Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
      match List.hd issues with
      | Issue.No_obj_magic { location } ->
          Alcotest.(check string) "correct file" temp_file location.file
      | _ -> Alcotest.fail "Expected No_obj_magic issue")
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let test_str_module_usage () =
  let content = "let pattern = Str.regexp \"[0-9]+\"" in
  let temp_file = create_temp_file content in

  match Merlin.get_parsetree temp_file with
  | Ok parsetree_result -> (
      let issues = Style.check ~filename:temp_file parsetree_result in
      Sys.remove temp_file;
      Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
      match List.hd issues with
      | Issue.Use_str_module { location } ->
          Alcotest.(check bool) "has location" true (location.file = temp_file)
      | _ -> Alcotest.fail "Expected Use_str_module issue")
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let test_catch_all_exception () =
  let content = "try Some (List.hd []) with _ -> None" in
  let temp_file = create_temp_file content in

  match Merlin.get_parsetree temp_file with
  | Ok parsetree_result -> (
      let issues = Style.check ~filename:temp_file parsetree_result in
      Sys.remove temp_file;
      Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
      match List.hd issues with
      | Issue.Catch_all_exception { location; _ } ->
          Alcotest.(check bool) "has location" true (location.file = temp_file)
      | _ -> Alcotest.fail "Expected Catch_all_exception issue")
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let test_multiple_issues () =
  let content =
    "let x = Obj.magic 42\n" ^ "let y = Str.regexp \"test\"\n"
    ^ "let z = try List.hd [] with _ -> 0"
  in
  let temp_file = create_temp_file content in

  match Merlin.get_parsetree temp_file with
  | Ok parsetree_result ->
      let issues = Style.check ~filename:temp_file parsetree_result in
      Sys.remove temp_file;
      Alcotest.(check int) "should have 3 issues" 3 (List.length issues)
  | Error _ ->
      Sys.remove temp_file;
      Alcotest.fail "Failed to parse test file"

let test_extract_location () =
  let text = "{\"line\":5,\"col\":10}" in
  match Style.extract_location_from_parsetree text with
  | Some (line, col) ->
      Alcotest.(check int) "line" 5 line;
      Alcotest.(check int) "col" 10 col
  | None -> Alcotest.fail "Failed to extract location"

let test_extract_filename () =
  let text = "(/path/to/file.ml[1,2..3,4])" in
  let filename = Style.extract_filename_from_parsetree text in
  Alcotest.(check string) "filename" "/path/to/file.ml" filename

let suite =
  [
    ( "style",
      [
        Alcotest.test_case "no style issues" `Quick test_no_style_issues;
        Alcotest.test_case "Obj.magic usage" `Quick test_obj_magic_usage;
        Alcotest.test_case "Str module usage" `Quick test_str_module_usage;
        Alcotest.test_case "catch-all exception" `Quick test_catch_all_exception;
        Alcotest.test_case "multiple issues" `Quick test_multiple_issues;
        Alcotest.test_case "extract location" `Quick test_extract_location;
        Alcotest.test_case "extract filename" `Quick test_extract_filename;
      ] );
  ]
