open Merlint

let test_analyze_file_valid () =
  (* Test with a valid OCaml file *)
  let temp_file = Filename.temp_file "test" ".ml" in
  let oc = open_out temp_file in
  output_string oc "let x = 42\nlet y = x + 1";
  close_out oc;

  let result = Merlin.analyze_file temp_file in
  Sys.remove temp_file;

  (* All analyses should succeed for valid file *)
  Alcotest.(check bool)
    "outline should succeed" true
    (Result.is_ok result.outline);
  Alcotest.(check bool)
    "parsetree should succeed" true
    (Result.is_ok result.parsetree);
  Alcotest.(check bool)
    "browse should succeed" true
    (Result.is_ok result.browse)

let test_analyze_file_syntax_error () =
  (* Test with invalid OCaml syntax *)
  let temp_file = Filename.temp_file "test" ".ml" in
  let oc = open_out temp_file in
  output_string oc "let x = (* unclosed comment";
  close_out oc;

  let result = Merlin.analyze_file temp_file in
  Sys.remove temp_file;

  (* All analyses should fail for invalid syntax *)
  Alcotest.(check bool)
    "outline should fail" true
    (Result.is_error result.outline);
  Alcotest.(check bool)
    "parsetree should fail" true
    (Result.is_error result.parsetree);
  Alcotest.(check bool)
    "browse should fail" true
    (Result.is_error result.browse)

let test_analyze_file_nonexistent () =
  let result = Merlin.analyze_file "/nonexistent/file.ml" in

  (* All analyses should fail for nonexistent file *)
  Alcotest.(check bool)
    "outline should fail" true
    (Result.is_error result.outline);
  Alcotest.(check bool)
    "parsetree should fail" true
    (Result.is_error result.parsetree);
  Alcotest.(check bool)
    "browse should fail" true
    (Result.is_error result.browse)

let test_get_outline () =
  let temp_file = Filename.temp_file "test" ".ml" in
  let oc = open_out temp_file in
  output_string oc "let foo x = x + 1\nlet bar = foo 42";
  close_out oc;

  let result = Merlin.get_outline temp_file in
  Sys.remove temp_file;

  match result with
  | Ok outline ->
      (* Should have two value entries *)
      let value_items =
        List.filter (fun item -> item.Outline.kind = Outline.Value) outline
      in
      Alcotest.(check int) "should have 2 values" 2 (List.length value_items)
  | Error msg -> Alcotest.fail (Fmt.str "get_outline failed: %s" msg)

let suite =
  [
    ( "merlin",
      [
        Alcotest.test_case "analyze valid file" `Quick test_analyze_file_valid;
        Alcotest.test_case "analyze file with syntax error" `Quick
          test_analyze_file_syntax_error;
        Alcotest.test_case "analyze nonexistent file" `Quick
          test_analyze_file_nonexistent;
        Alcotest.test_case "get outline" `Quick test_get_outline;
      ] );
  ]
