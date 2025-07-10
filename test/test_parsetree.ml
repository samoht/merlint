(** Tests for Parsetree module *)

open Merlint.Parsetree

let test_parse_empty () =
  let json = `String "" in
  let result = of_json json in
  Alcotest.(check bool) "no function" false (has_function result);
  Alcotest.(check bool) "no match" false (has_pattern_matching result);
  Alcotest.(check int) "no cases" 0 (get_case_count result)

let test_parse_with_function () =
  let json =
    `String
      "structure_item (test.ml[1,0+0]..[3,50+1])\n\
      \  Pstr_value Nonrec\n\
      \    value_binding (test.ml[1,4+0]..[3,50+1])\n\
      \      Ppat_var \"foo\" (test.ml[1,8+4]..[1,8+7])\n\
      \      Pexp_fun"
  in
  let result = of_json json in
  Alcotest.(check bool) "has function" true (has_function result);
  Alcotest.(check bool) "no match" false (has_pattern_matching result)

let test_parse_with_match () =
  let json =
    `String
      "Pexp_match (test.ml[2,10+5]..[5,50+1])\n\
      \  Pexp_ident \"x\"\n\
      \  case\n\
      \    Ppat_construct \"Some\"\n\
      \  case\n\
      \    Ppat_construct \"None\""
  in
  let result = of_json json in
  Alcotest.(check bool) "has match" true (has_pattern_matching result);
  Alcotest.(check int) "case count" 2 (get_case_count result)

let test_parse_function_cases () =
  let json =
    `String
      "Pexp_function (test.ml[1,0+0]..[10,100+1])\n\
      \  case\n\
      \    pattern\n\
      \  case\n\
      \    pattern\n\
      \  case\n\
      \    pattern"
  in
  let result = of_json json in
  Alcotest.(check bool) "has match" true (has_pattern_matching result);
  Alcotest.(check int) "case count" 3 (get_case_count result)

let test_pp () =
  let t =
    { has_function = true; has_match = true; case_count = 5; raw_text = "" }
  in
  let str = Fmt.str "%a" pp t in
  Alcotest.(check string)
    "pretty print" "{ function: true; match: true; cases: 5 }" str

let tests =
  [
    Alcotest.test_case "parse_empty" `Quick test_parse_empty;
    Alcotest.test_case "parse_with_function" `Quick test_parse_with_function;
    Alcotest.test_case "parse_with_match" `Quick test_parse_with_match;
    Alcotest.test_case "parse_function_cases" `Quick test_parse_function_cases;
    Alcotest.test_case "pp" `Quick test_pp;
  ]

let suite = [ ("parsetree", tests) ]
