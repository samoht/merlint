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
    Location.create_extended ~file:"test.ml" ~start_line:1 ~start_col:0
      ~end_line:60 ~end_col:0
  in
  let browse_value : Browse.t =
    {
      value_bindings =
        [
          {
            name = Some "test_func";
            location = Some loc;
            pattern_info = { has_pattern_match = false; case_count = 0 };
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
    Location.create_extended ~file:"test.ml" ~start_line:1 ~start_col:0
      ~end_line:80 ~end_col:0
  in
  let browse_value : Browse.t =
    {
      value_bindings =
        [
          {
            name = Some "test_func";
            location = Some loc;
            pattern_info = { has_pattern_match = true; case_count = 15 };
          };
        ];
    }
  in

  let issues = Complexity.analyze_browse_value config browse_value in
  (* Function is 80 lines but has pattern matching with >10 cases, threshold doubles to 100 *)
  Alcotest.(check int)
    "no issues with pattern adjustment" 0 (List.length issues)

let suite =
  [
    ( "complexity",
      [
        Alcotest.test_case "default config" `Quick default_config;
        Alcotest.test_case "analyze browse value" `Quick analyze_browse_value;
        Alcotest.test_case "analyze browse value with pattern" `Quick
          browse_value_with_pattern;
      ] );
  ]
