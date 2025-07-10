(** Tests for Typedtree module *)

open Merlint.Typedtree

let test_parse_empty () =
  let json = `String "" in
  let result = of_json json in
  Alcotest.(check bool) "no pattern match" false (has_pattern_matching result);
  Alcotest.(check int) "no cases" 0 (get_case_count result)

let test_parse_with_match () =
  let json =
    `String
      "expression (test.ml[2,10+5]..[5,50+1])\n\
      \  Texp_match\n\
      \    expression\n\
      \    case\n\
      \      pattern\n\
      \    case\n\
      \      pattern"
  in
  let result = of_json json in
  Alcotest.(check bool) "has pattern match" true (has_pattern_matching result);
  Alcotest.(check int) "case count" 2 (get_case_count result)

let test_parse_function_cases () =
  let json =
    `String
      "value_binding\n\
      \  pattern\n\
      \  Tfunction_cases\n\
      \    case\n\
      \      pattern\n\
      \    case\n\
      \      pattern\n\
      \    case\n\
      \      pattern"
  in
  let result = of_json json in
  Alcotest.(check bool) "has pattern match" true (has_pattern_matching result);
  Alcotest.(check int) "case count" 3 (get_case_count result)

let test_parse_non_string () =
  let json = `Assoc [ ("kind", `String "expression") ] in
  let result = of_json json in
  Alcotest.(check bool) "no pattern match" false (has_pattern_matching result);
  Alcotest.(check int) "no cases" 0 (get_case_count result)

let test_pp () =
  let t = { has_pattern_match = true; case_count = 10; function_info = None } in
  let str = Fmt.str "%a" pp t in
  Alcotest.(check string)
    "pretty print" "{ pattern_match: true; cases: 10 }" str

let tests =
  [
    Alcotest.test_case "parse_empty" `Quick test_parse_empty;
    Alcotest.test_case "parse_with_match" `Quick test_parse_with_match;
    Alcotest.test_case "parse_function_cases" `Quick test_parse_function_cases;
    Alcotest.test_case "parse_non_string" `Quick test_parse_non_string;
    Alcotest.test_case "pp" `Quick test_pp;
  ]

let suite = [ ("typedtree", tests) ]
