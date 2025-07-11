(** Tests for Typedtree module *)

open Merlint.Typedtree

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
      \  Tstr_value Nonrec\n\
      \    <def>\n\
      \      Tpat_var \"foo/123\" (test.ml[1,8+4]..[1,8+7])\n\
      \      Texp_function"
  in
  let result = of_json json in
  Alcotest.(check bool) "has function" true (has_function result);
  Alcotest.(check bool) "no match" false (has_pattern_matching result)

let test_parse_with_match () =
  let json =
    `String
      "structure_item (test.ml[1,0+0]..test.ml[1,0+46])\n\
      \  Tstr_value Nonrec\n\
      \  [\n\
      \    <def>\n\
      \      pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
      \        Tpat_var \"x/276\"\n\
      \      expression (test.ml[1,0+8]..test.ml[1,0+46])\n\
      \        Texp_match\n\
      \        expression (test.ml[1,0+14]..test.ml[1,0+15])\n\
      \          Texp_ident \"y/277\"\n\
      \        [\n\
      \          <case>\n\
      \            pattern (test.ml[1,0+23]..test.ml[1,0+29])\n\
      \              Tpat_construct \"Some\"\n\
      \          <case>\n\
      \            pattern (test.ml[1,0+37]..test.ml[1,0+41])\n\
      \              Tpat_construct \"None\"\n\
      \        ]\n\
      \  ]"
  in
  let result = of_json json in
  Alcotest.(check bool) "has match" true (has_pattern_matching result);
  Alcotest.(check int) "case count" 2 (get_case_count result)

let test_parse_function_cases () =
  let json =
    `String
      "Texp_function (test.ml[1,0+0]..[10,100+1])\n\
      \  <case>\n\
      \    pattern\n\
      \  <case>\n\
      \    pattern\n\
      \  <case>\n\
      \    pattern"
  in
  let result = of_json json in
  Alcotest.(check bool) "has match" true (has_pattern_matching result);
  Alcotest.(check int) "case count" 3 (get_case_count result)

let tests =
  [
    Alcotest.test_case "parse_empty" `Quick test_parse_empty;
    Alcotest.test_case "parse_with_function" `Quick test_parse_with_function;
    Alcotest.test_case "parse_with_match" `Quick test_parse_with_match;
    Alcotest.test_case "parse_function_cases" `Quick test_parse_function_cases;
  ]

let suite = [ ("typedtree", tests) ]
