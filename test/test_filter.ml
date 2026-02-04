open Alcotest
open Merlint

let test_parse_range () =
  (* Test simple range *)
  match Filter.parse "all-100..199" with
  | Ok filter ->
      check bool "E001 enabled" true (Filter.is_enabled_by_code filter "E001");
      check bool "E100 disabled" false (Filter.is_enabled_by_code filter "E100");
      check bool "E105 disabled" false (Filter.is_enabled_by_code filter "E105");
      check bool "E200 enabled" true (Filter.is_enabled_by_code filter "E200")
  | Error msg -> fail msg

let test_parse_exclusions () =
  (* Test exclusion syntax *)
  match Filter.parse "all-E110-E205" with
  | Ok filter ->
      check bool "E001 enabled" true (Filter.is_enabled_by_code filter "E001");
      check bool "E110 disabled" false (Filter.is_enabled_by_code filter "E110");
      check bool "E205 disabled" false (Filter.is_enabled_by_code filter "E205");
      check bool "E200 enabled" true (Filter.is_enabled_by_code filter "E200")
  | Error msg -> fail msg

let test_parse_selective () =
  (* Test selective enabling *)
  match Filter.parse "E300+E305" with
  | Ok filter ->
      check bool "E300 enabled" true (Filter.is_enabled_by_code filter "E300");
      check bool "E305 enabled" true (Filter.is_enabled_by_code filter "E305");
      check bool "E001 disabled" false (Filter.is_enabled_by_code filter "E001");
      check bool "E200 disabled" false (Filter.is_enabled_by_code filter "E200")
  | Error msg -> fail msg

let test_parse_single () =
  (* Test single rule *)
  match Filter.parse "E300" with
  | Ok filter ->
      check bool "E300 enabled" true (Filter.is_enabled_by_code filter "E300");
      check bool "E001 disabled" false (Filter.is_enabled_by_code filter "E001");
      check bool "E200 disabled" false (Filter.is_enabled_by_code filter "E200")
  | Error msg -> fail msg

let test_parse_mixed () =
  (* Test mixed format: 300..399-E320 *)
  match Filter.parse "300..399-E320" with
  | Ok filter ->
      check bool "E300 enabled" true (Filter.is_enabled_by_code filter "E300");
      check bool "E305 enabled" true (Filter.is_enabled_by_code filter "E305");
      check bool "E320 disabled" false (Filter.is_enabled_by_code filter "E320");
      check bool "E001 disabled" false (Filter.is_enabled_by_code filter "E001")
  | Error msg -> fail msg

let test_parse_errors () =
  (* Skip - error validation not implemented *)
  ()

let tests =
  [
    test_case "parse range" `Quick test_parse_range;
    test_case "parse exclusions" `Quick test_parse_exclusions;
    test_case "parse selective" `Quick test_parse_selective;
    test_case "parse single" `Quick test_parse_single;
    test_case "parse mixed format" `Quick test_parse_mixed;
    test_case "parse errors" `Quick test_parse_errors;
  ]

let suite = ("filter", tests)
