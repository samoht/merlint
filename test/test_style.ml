open Merlint

(* Helper to create mock typedtree data *)
let mock_location file line col =
  Location.
    {
      file;
      start_line = line;
      start_col = col;
      end_line = line;
      end_col = col + 1;
    }

let mock_name ?(prefix = []) base = Typedtree.{ prefix; base }

let mock_identifier ?(prefix = []) base ?location () =
  let location =
    match location with
    | Some loc -> Some loc
    | None -> Some (mock_location "test.ml" 1 1)
  in
  Typedtree.{ name = mock_name ~prefix base; location }

let mock_pattern base ?location () =
  let location =
    match location with
    | Some loc -> Some loc
    | None -> Some (mock_location "test.ml" 1 1)
  in
  Typedtree.{ name = mock_name base; location }

let test_no_style_issues () =
  let typedtree =
    Typedtree.
      {
        identifiers = [ mock_identifier "safe_function" () ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Style.check typedtree in
  Alcotest.(check int) "no style issues" 0 (List.length issues)

let test_obj_magic_usage () =
  let typedtree =
    Typedtree.
      {
        identifiers = [ mock_identifier ~prefix:[ "Stdlib"; "Obj" ] "magic" () ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Style.check typedtree in
  Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
  match List.hd issues with
  | Issue.No_obj_magic { location } ->
      Alcotest.(check string) "correct file" "test.ml" location.file
  | _ -> Alcotest.fail "Expected No_obj_magic issue"

let test_str_module_usage () =
  let typedtree =
    Typedtree.
      {
        identifiers =
          [ mock_identifier ~prefix:[ "Stdlib"; "Str" ] "regexp" () ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Style.check typedtree in
  Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
  match List.hd issues with
  | Issue.Use_str_module { location } ->
      Alcotest.(check string) "correct file" "test.ml" location.file
  | _ -> Alcotest.fail "Expected Use_str_module issue"

let test_catch_all_exception () =
  let typedtree =
    Typedtree.
      {
        identifiers = [];
        patterns = [ mock_pattern "_" () ];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Style.check typedtree in
  Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
  match List.hd issues with
  | Issue.Catch_all_exception { location } ->
      Alcotest.(check string) "correct file" "test.ml" location.file
  | _ -> Alcotest.fail "Expected Catch_all_exception issue"

let test_multiple_issues () =
  let typedtree =
    Typedtree.
      {
        identifiers =
          [
            mock_identifier ~prefix:[ "Stdlib"; "Obj" ] "magic" ();
            mock_identifier ~prefix:[ "Stdlib"; "Printf" ] "printf" ();
          ];
        patterns = [ mock_pattern "_" () ];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Style.check typedtree in
  Alcotest.(check int) "should have 3 issues" 3 (List.length issues)

let test_extract_location () =
  let text = "(test.ml[5,8+10])" in
  match Style.extract_location_from_parsetree text with
  | Some (line, col) ->
      Alcotest.(check int) "line" 5 line;
      Alcotest.(check int) "col" 10 col
  | None -> Alcotest.fail "Failed to extract location"

let test_extract_filename () =
  let text = "(/path/to/file.ml[1,2..3,4])" in
  let filename = Style.extract_filename_from_parsetree text in
  Alcotest.(check string) "filename" "/path/to/file.ml" filename

let test_error_pattern () =
  let loc = Some (mock_location "test.ml" 5 12) in
  let typedtree =
    Typedtree.
      {
        identifiers = [];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions =
          [
            ( Construct
                {
                  name = "Error";
                  args =
                    [
                      Apply
                        {
                          func = Ident "Fmt.str";
                          args = [ Constant "Invalid data" ];
                        };
                    ];
                },
              loc );
          ];
      }
  in
  let issues = Style.check typedtree in
  Alcotest.(check int) "Error pattern detected" 1 (List.length issues);
  match List.hd issues with
  | Issue.Error_pattern { location; _ } ->
      Alcotest.(check string) "correct file" "test.ml" location.file
  | _ -> Alcotest.fail "Expected Error_pattern issue"

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
        Alcotest.test_case "error pattern" `Quick test_error_pattern;
      ] );
  ]
