open Merlint

let create_temp_file content =
  let temp_file = Filename.temp_file "test_warning" ".ml" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;
  temp_file

let test_no_warnings_silenced () =
  let content = "let clean_code x = x + 1\nlet y = clean_code 42" in
  let files = [ create_temp_file content ] in

  let issues = Warning_checks.check files in
  List.iter Sys.remove files;

  Alcotest.(check int) "no warning issues" 0 (List.length issues)

let test_warning_attribute () =
  let content = "[@warning \"-32\"]\nlet unused_value = 42" in
  let temp_file = create_temp_file content in

  let issues = Warning_checks.check [ temp_file ] in
  Sys.remove temp_file;

  Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
  match List.hd issues with
  | Issue.Silenced_warning { warning_number; _ } ->
      Alcotest.(check string) "warning number" "32" warning_number
  | _ -> Alcotest.fail "Expected Silenced_warning issue"

let test_warning_annotation () =
  let content = "let unused_value = 42 [@@warning \"-26\"]" in
  let temp_file = create_temp_file content in

  let issues = Warning_checks.check [ temp_file ] in
  Sys.remove temp_file;

  Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
  match List.hd issues with
  | Issue.Silenced_warning { warning_number; _ } ->
      Alcotest.(check string) "warning number" "26" warning_number
  | _ -> Alcotest.fail "Expected Silenced_warning issue"

let test_multiple_warnings () =
  let content =
    "[@warning \"-32\"]\n" ^ "let unused1 = 42\n" ^ "[@warning \"-27\"]\n"
    ^ "let unused2 = 24\n" ^ "let unused3 = 12 [@@warning \"-26\"]\n"
  in
  let temp_file = create_temp_file content in

  let issues = Warning_checks.check [ temp_file ] in
  Sys.remove temp_file;

  Alcotest.(check int) "should have 3 issues" 3 (List.length issues);

  (* Check that we found all warning numbers *)
  let warning_numbers =
    List.map
      (function
        | Issue.Silenced_warning { warning_number; _ } -> warning_number
        | _ -> "unexpected")
      issues
  in

  List.iter
    (fun num ->
      Alcotest.(check bool)
        (Fmt.str "found warning %s" num)
        true
        (List.mem num warning_numbers))
    [ "32"; "27"; "26" ]

let test_check_multiple_files () =
  let file1 = create_temp_file "let x = 1 [@warning \"-32\"]" in
  let file2 = create_temp_file "[@warning \"-26\"]\nlet y = 2" in
  let file3 = create_temp_file "let z = 3" in
  (* No warnings *)

  let issues = Warning_checks.check [ file1; file2; file3 ] in

  List.iter Sys.remove [ file1; file2; file3 ];

  Alcotest.(check int) "should have 2 issues" 2 (List.length issues);

  (* Check that issues come from correct files *)
  let files_with_issues =
    List.map
      (function
        | Issue.Silenced_warning { location; _ } ->
            Filename.basename location.file
        | _ -> "unexpected")
      issues
  in

  Alcotest.(check bool)
    "file1 has issue" true
    (List.exists (fun f -> f = Filename.basename file1) files_with_issues);
  Alcotest.(check bool)
    "file2 has issue" true
    (List.exists (fun f -> f = Filename.basename file2) files_with_issues)

let suite =
  [
    ( "warning_checks",
      [
        Alcotest.test_case "no warnings silenced" `Quick
          test_no_warnings_silenced;
        Alcotest.test_case "warning attribute" `Quick test_warning_attribute;
        Alcotest.test_case "warning annotation" `Quick test_warning_annotation;
        Alcotest.test_case "multiple warnings" `Quick test_multiple_warnings;
        Alcotest.test_case "check multiple files" `Quick
          test_check_multiple_files;
      ] );
  ]
