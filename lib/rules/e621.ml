(** E621: Empty Test Suite *)

type payload = { suite_name : string }

let check =
  Suite.check_empty ~prefix:"test" ~mk_payload:(fun suite_name ->
      { suite_name })

let pp ppf { suite_name } =
  Fmt.pf ppf
    "Test suite '%s' is empty — add meaningful tests covering the public API, \
     edge cases, and error paths"
    suite_name

let rule =
  Rule.v ~code:"E621" ~title:"Empty Test Suite" ~category:Testing
    ~hint:
      "An empty test suite provides no value. Tests should: (1) cover the \
       module's public API with representative inputs, (2) exercise boundary \
       conditions and edge cases, (3) verify error handling and invalid \
       inputs, (4) document expected behaviour through concrete examples. A \
       suite with no test cases will never catch regressions."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let suite = ("parser", [])  (* no tests: regressions go undetected *)|};
        };
        {
          is_good = true;
          code =
            {|let suite =
  ( "parser",
    [
      Alcotest.test_case "parses valid input" `Quick test_parse_valid;
      Alcotest.test_case "rejects empty input" `Quick test_parse_empty;
      Alcotest.test_case "handles malformed data" `Quick test_parse_malformed;
    ] )|};
        };
      ]
    ~pp (File check)
