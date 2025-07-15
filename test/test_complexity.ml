open Merlint

let default_config () =
  let config = Complexity.default_config in
  Alcotest.(check int) "default max_complexity" 10 config.max_complexity;
  Alcotest.(check int)
    "default max_function_length" 50 config.max_function_length;
  Alcotest.(check int) "default max_nesting" 3 config.max_nesting

let analyze_browse_value () =
  let config = Complexity.default_config in
  (* Create a mock browse value *)
  let loc =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:60
      ~end_col:0
  in
  let browse_value : Browse.t =
    {
      value_bindings =
        [
          {
            ast_elt =
              { Ast.name = Ast.parse_name "test_func"; location = Some loc };
            pattern_info = { has_pattern_match = false; case_count = 0 };
            is_function = true;
            is_simple_list = false;
          };
        ];
    }
  in

  let issues = Complexity.analyze_browse_value config browse_value in
  (* Function is 60 lines, should trigger Function_too_long *)
  match issues with
  | [ Issue.Function_too_long { name; length; threshold; _ } ] ->
      Alcotest.(check string) "function name" "test_func" name;
      Alcotest.(check int) "length" 60 length;
      Alcotest.(check int) "threshold" 50 threshold
  | _ -> Alcotest.fail "Expected Function_too_long issue"

let browse_value_with_pattern () =
  let config = Complexity.default_config in
  (* Create a mock browse value with pattern matching *)
  let loc =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:80
      ~end_col:0
  in
  let browse_value : Browse.t =
    {
      value_bindings =
        [
          {
            ast_elt =
              { Ast.name = Ast.parse_name "test_func"; location = Some loc };
            pattern_info = { has_pattern_match = true; case_count = 15 };
            is_function = true;
            is_simple_list = false;
          };
        ];
    }
  in

  let issues = Complexity.analyze_browse_value config browse_value in
  (* Function is 80 lines but has pattern matching with >10 cases, threshold doubles to 100 *)
  Alcotest.(check int)
    "no issues with pattern adjustment" 0 (List.length issues)

let long_data_structure_exempt () =
  let config = Complexity.default_config in
  (* Create a long data structure (list or record) - should be exempt from length check *)
  let loc =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:60
      ~end_col:0
  in
  let browse_value : Browse.t =
    {
      value_bindings =
        [
          {
            ast_elt =
              { Ast.name = Ast.parse_name "my_data"; location = Some loc };
            pattern_info = { has_pattern_match = false; case_count = 0 };
            is_function = false;
            is_simple_list = true;
          };
        ];
    }
  in

  let issues = Complexity.analyze_browse_value config browse_value in
  (* Data structure is 60 lines but should be exempt from length check *)
  Alcotest.(check int)
    "no issues for long data structure" 0 (List.length issues)

let complex_value_not_exempt () =
  let config = Complexity.default_config in
  (* Create a long complex value (not a simple data structure) - should NOT be exempt *)
  let loc =
    Location.create ~file:"test.ml" ~start_line:1 ~start_col:0 ~end_line:60
      ~end_col:0
  in
  let browse_value : Browse.t =
    {
      value_bindings =
        [
          {
            ast_elt =
              { Ast.name = Ast.parse_name "complex_value"; location = Some loc };
            pattern_info = { has_pattern_match = false; case_count = 0 };
            is_function = false;
            is_simple_list = false;
          };
        ];
    }
  in

  let issues = Complexity.analyze_browse_value config browse_value in
  (* Complex value is 60 lines, should trigger Function_too_long *)
  match issues with
  | [ Issue.Function_too_long { name; length; threshold; _ } ] ->
      Alcotest.(check string) "value name" "complex_value" name;
      Alcotest.(check int) "length" 60 length;
      Alcotest.(check int) "threshold" 50 threshold
  | _ -> Alcotest.fail "Expected Function_too_long issue for complex value"

let suite =
  [
    ( "complexity",
      [
        Alcotest.test_case "default config" `Quick default_config;
        Alcotest.test_case "analyze browse value" `Quick analyze_browse_value;
        Alcotest.test_case "analyze browse value with pattern" `Quick
          browse_value_with_pattern;
        Alcotest.test_case "long data structure is exempt" `Quick
          long_data_structure_exempt;
        Alcotest.test_case "long complex value is not exempt" `Quick
          complex_value_not_exempt;
      ] );
  ]
