open Merlint

(* Helper to create mock location *)
let mock_location file line col =
  Location.
    {
      file;
      start_line = line;
      start_col = col;
      end_line = line;
      end_col = col + 1;
    }

(* Helper to create mock identifiers *)
let mock_identifier ?(_prefix = []) base ?location () =
  let location =
    match location with
    | Some loc -> Some loc
    | None -> Some (mock_location "test.ml" 1 1)
  in
  Ast.{ name = Ast.parse_name ~handle_bang_suffix:true base; location }

let snake_case_valid () =
  let typedtree =
    Typedtree.
      {
        identifiers =
          [ mock_identifier "my_function" (); mock_identifier "another_var" () ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Naming.check ~filename:"test.ml" ~outline:None typedtree in
  Alcotest.(check int) "no naming issues" 0 (List.length issues)

let camel_case_violation () =
  let typedtree =
    Typedtree.
      {
        identifiers =
          [ mock_identifier "myFunction" (); mock_identifier "anotherVar" () ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Naming.check ~filename:"test.ml" ~outline:None typedtree in
  Alcotest.(check int) "should have 2 issues" 2 (List.length issues);
  (* Check that issues are for the expected identifiers *)
  List.iter
    (function
      | Issue.Bad_value_naming { value_name; _ } ->
          Alcotest.(check bool)
            "should be camelCase"
            (value_name = "myFunction" || value_name = "anotherVar")
            true
      | Issue.Bad_function_naming { function_name; _ } ->
          Alcotest.(check bool)
            "should be camelCase"
            (function_name = "myFunction" || function_name = "anotherVar")
            true
      | _ -> Alcotest.fail "Expected naming issue")
    issues

let too_many_underscores () =
  let typedtree =
    Typedtree.
      {
        identifiers = [ mock_identifier "very_long_function_name" () ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Naming.check ~filename:"test.ml" ~outline:None typedtree in
  Alcotest.(check int) "should have 1 issue" 1 (List.length issues);
  match List.hd issues with
  | Issue.Long_identifier_name { name; underscore_count; _ } ->
      Alcotest.(check string) "name" "very_long_function_name" name;
      Alcotest.(check bool) "has many underscores" true (underscore_count > 3)
  | _ -> Alcotest.fail "Expected Long_identifier_name issue"

let module_naming () =
  let typedtree =
    Typedtree.
      {
        identifiers = [];
        patterns = [];
        modules =
          [
            {
              Ast.name = Ast.parse_name ~handle_bang_suffix:true "MyModule";
              location = Some (mock_location "test.ml" 2 0);
            };
            {
              Ast.name = Ast.parse_name ~handle_bang_suffix:true "AnotherModule";
              location = Some (mock_location "test.ml" 5 0);
            };
            {
              Ast.name = Ast.parse_name ~handle_bang_suffix:true "Already_snake";
              location = Some (mock_location "test.ml" 8 0);
            };
          ];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Naming.check ~filename:"test.ml" ~outline:None typedtree in
  let module_issues =
    List.filter
      (fun issue ->
        match issue with Issue.Bad_module_naming _ -> true | _ -> false)
      issues
  in
  (* MyModule and AnotherModule should be flagged, but not Already_snake *)
  Alcotest.(check int)
    "should have 2 module naming issues" 2
    (List.length module_issues);

  List.iter
    (fun issue ->
      match issue with
      | Issue.Bad_module_naming { module_name; expected; _ } ->
          if module_name = "MyModule" then
            Alcotest.(check string)
              "MyModule should become My_module" "My_module" expected
          else if module_name = "AnotherModule" then
            Alcotest.(check string)
              "AnotherModule should become Another_module" "Another_module"
              expected
      | _ -> ())
    module_issues

let type_naming () =
  let typedtree =
    Typedtree.
      {
        identifiers = [];
        patterns = [];
        modules = [];
        types =
          [
            {
              Ast.name = Ast.parse_name ~handle_bang_suffix:true "my_type";
              location = Some (mock_location "test.ml" 1 5);
            };
            {
              Ast.name = Ast.parse_name ~handle_bang_suffix:true "AnotherType";
              location = Some (mock_location "test.ml" 2 5);
            };
          ];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Naming.check ~filename:"test.ml" ~outline:None typedtree in
  (* Both snake_case and PascalCase are valid for types *)
  Alcotest.(check int) "no issues for type names" 0 (List.length issues)

let detect_used_underscore () =
  let typedtree =
    Typedtree.
      {
        identifiers =
          [
            mock_identifier "_unused" ~location:(mock_location "test.ml" 2 4) ();
            mock_identifier "_used" ~location:(mock_location "test.ml" 3 4) ();
            mock_identifier "normal" ~location:(mock_location "test.ml" 4 4) ();
            (* Usage of _used in the function *)
            mock_identifier "_used" ~location:(mock_location "test.ml" 7 16) ();
            mock_identifier "normal" ~location:(mock_location "test.ml" 8 12) ();
          ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Naming.check ~filename:"test.ml" ~outline:None typedtree in
  (* Should detect _used but not _unused or normal *)
  let underscore_issues =
    List.filter
      (fun issue ->
        match issue with Issue.Used_underscore_binding _ -> true | _ -> false)
      issues
  in
  Alcotest.(check int)
    "number of underscore binding issues" 1
    (List.length underscore_issues);

  match List.hd underscore_issues with
  | Issue.Used_underscore_binding { binding_name; _ } ->
      Alcotest.(check string) "binding name" "_used" binding_name
  | _ -> Alcotest.fail "Expected Used_underscore_binding issue"

let no_false_positives_underscore () =
  let typedtree =
    Typedtree.
      {
        identifiers =
          [
            mock_identifier "normal_var" ();
            mock_identifier "another_var" ();
            mock_identifier "normal_var" ();
            mock_identifier "another_var" ();
          ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Naming.check ~filename:"test.ml" ~outline:None typedtree in
  let underscore_issues =
    List.filter
      (fun issue ->
        match issue with Issue.Used_underscore_binding _ -> true | _ -> false)
      issues
  in
  Alcotest.(check int)
    "no underscore binding issues" 0
    (List.length underscore_issues)

let multiple_underscore_usages () =
  let typedtree =
    Typedtree.
      {
        identifiers =
          [
            mock_identifier "_temp" ~location:(mock_location "test.ml" 2 4) ();
            mock_identifier "_temp" ~location:(mock_location "test.ml" 5 16) ();
            mock_identifier "_temp" ~location:(mock_location "test.ml" 6 16) ();
          ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  let issues = Naming.check ~filename:"test.ml" ~outline:None typedtree in
  let underscore_issues =
    List.filter
      (fun issue ->
        match issue with Issue.Used_underscore_binding _ -> true | _ -> false)
      issues
  in
  Alcotest.(check int)
    "one issue for multiple usages" 1
    (List.length underscore_issues);

  match List.hd underscore_issues with
  | Issue.Used_underscore_binding { usage_locations; _ } ->
      Alcotest.(check int)
        "number of usage locations" 2
        (List.length usage_locations)
  | _ -> Alcotest.fail "Expected Used_underscore_binding issue"

let suite =
  [
    ( "naming",
      [
        Alcotest.test_case "valid snake_case" `Quick snake_case_valid;
        Alcotest.test_case "camelCase violation" `Quick camel_case_violation;
        Alcotest.test_case "too many underscores" `Quick too_many_underscores;
        Alcotest.test_case "module naming" `Quick module_naming;
        Alcotest.test_case "type naming" `Quick type_naming;
        Alcotest.test_case "detect used underscore binding" `Quick
          detect_used_underscore;
        Alcotest.test_case "no false positives for underscore bindings" `Quick
          no_false_positives_underscore;
        Alcotest.test_case "multiple underscore usages" `Quick
          multiple_underscore_usages;
      ] );
  ]
