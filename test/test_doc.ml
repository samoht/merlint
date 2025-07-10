open Merlint

let write_temp_file content =
  let filename = Filename.temp_file "test_doc" ".mli" in
  let oc = open_out filename in
  output_string oc content;
  close_out oc;
  filename

let test_check_mli_files_with_doc () =
  let content =
    "(** This module has documentation *)\n\nval foo : unit -> unit"
  in
  let filename = write_temp_file content in
  let issues = Doc.check_mli_files [ filename ] in
  Sys.remove filename;
  Alcotest.(check int) "no issues" 0 (List.length issues)

let test_check_mli_files_missing_doc () =
  let content = "val foo : unit -> unit\n(** This doc comes too late *)" in
  let filename = write_temp_file content in
  let issues = Doc.check_mli_files [ filename ] in
  Sys.remove filename;
  match issues with
  | [ Issue.Missing_mli_doc { module_name; file } ] ->
      Alcotest.(check string) "module name" "test_doc" module_name;
      Alcotest.(check string) "file" filename file
  | _ -> Alcotest.fail "Expected one Missing_mli_doc issue"

let test_check_mli_files_empty_file () =
  let content = "" in
  let filename = write_temp_file content in
  let issues = Doc.check_mli_files [ filename ] in
  Sys.remove filename;
  match issues with
  | [ Issue.Missing_mli_doc { module_name; _ } ] ->
      Alcotest.(check string) "module name" "test_doc" module_name
  | _ -> Alcotest.fail "Expected Missing_mli_doc issue for empty file"

let test_check_mli_files_whitespace_then_doc () =
  let content = "\n\n   \n(** Module documentation *)\n\nval foo : unit" in
  let filename = write_temp_file content in
  let issues = Doc.check_mli_files [ filename ] in
  Sys.remove filename;
  Alcotest.(check int)
    "no issues with doc after whitespace" 0 (List.length issues)

let test_check_mli_files () =
  let mli_file = write_temp_file "val foo : unit" in
  let ml_file = Filename.temp_file "test" ".ml" in
  let oc = open_out ml_file in
  output_string oc "let foo = ()";
  close_out oc;

  let files = [ mli_file; ml_file; "nonexistent.mli" ] in
  let issues = Doc.check_mli_files files in

  Sys.remove mli_file;
  Sys.remove ml_file;

  (* Should only check .mli files and handle missing files gracefully *)
  Alcotest.(check int) "one issue from mli file" 1 (List.length issues)

let suite =
  [
    ( "doc",
      [
        Alcotest.test_case "with documentation" `Quick
          test_check_mli_files_with_doc;
        Alcotest.test_case "missing documentation" `Quick
          test_check_mli_files_missing_doc;
        Alcotest.test_case "empty file" `Quick test_check_mli_files_empty_file;
        Alcotest.test_case "whitespace then doc" `Quick
          test_check_mli_files_whitespace_then_doc;
        Alcotest.test_case "check mli files" `Quick test_check_mli_files;
      ] );
  ]
