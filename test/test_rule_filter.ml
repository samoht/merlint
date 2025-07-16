open Alcotest
open Merlint

let test_parse_range () =
  (* Test simple range *)
  match Filter.parse "all-100..199" with
  | Ok filter ->
      check bool "E001 enabled" true (Filter.is_enabled filter Issue.Complexity);
      check bool "E100 disabled" false
        (Filter.is_enabled filter Issue.Obj_magic);
      check bool "E105 disabled" false
        (Filter.is_enabled filter Issue.Catch_all_exception);
      check bool "E200 enabled" true (Filter.is_enabled filter Issue.Str_module)
  | Error msg -> fail msg

let test_parse_exclusions () =
  (* Test exclusion syntax *)
  match Filter.parse "all-E110-E205" with
  | Ok filter ->
      check bool "E001 enabled" true (Filter.is_enabled filter Issue.Complexity);
      check bool "E110 disabled" false
        (Filter.is_enabled filter Issue.Silenced_warning);
      check bool "E205 disabled" false
        (Filter.is_enabled filter Issue.Printf_module);
      check bool "E200 enabled" true (Filter.is_enabled filter Issue.Str_module)
  | Error msg -> fail msg

let test_parse_selective () =
  (* Test selective enabling *)
  match Filter.parse "E300+E305" with
  | Ok filter ->
      check bool "E300 enabled" true
        (Filter.is_enabled filter Issue.Variant_naming);
      check bool "E305 enabled" true
        (Filter.is_enabled filter Issue.Module_naming);
      check bool "E001 disabled" false
        (Filter.is_enabled filter Issue.Complexity);
      check bool "E200 disabled" false
        (Filter.is_enabled filter Issue.Str_module)
  | Error msg -> fail msg

let test_parse_single () =
  (* Test single rule *)
  match Filter.parse "E300" with
  | Ok filter ->
      check bool "E300 enabled" true
        (Filter.is_enabled filter Issue.Variant_naming);
      check bool "E001 disabled" false
        (Filter.is_enabled filter Issue.Complexity);
      check bool "E200 disabled" false
        (Filter.is_enabled filter Issue.Str_module)
  | Error msg -> fail msg

let test_parse_mixed () =
  (* Test mixed format *)
  match Filter.parse "300..399-E320" with
  | Ok filter ->
      check bool "E300 enabled" true
        (Filter.is_enabled filter Issue.Variant_naming);
      check bool "E305 enabled" true
        (Filter.is_enabled filter Issue.Module_naming);
      check bool "E320 disabled" false
        (Filter.is_enabled filter Issue.Long_identifier);
      check bool "E001 disabled" false
        (Filter.is_enabled filter Issue.Complexity)
  | Error msg -> fail msg

let test_parse_errors () =
  (* Test error cases *)
  (match Filter.parse "invalid" with
  | Ok _ -> fail "Should have failed for invalid spec"
  | Error _ -> ());

  match Filter.parse "E999" with
  | Ok _ -> fail "Should have failed for unknown error code"
  | Error msg ->
      check bool "error mentions unknown code" true
        (Astring.String.is_infix ~affix:"Unknown error code" msg)

let tests =
  [
    test_case "parse range" `Quick test_parse_range;
    test_case "parse exclusions" `Quick test_parse_exclusions;
    test_case "parse selective" `Quick test_parse_selective;
    test_case "parse single" `Quick test_parse_single;
    test_case "parse mixed format" `Quick test_parse_mixed;
    test_case "parse errors" `Quick test_parse_errors;
  ]

let suite = ("Rule_filter", tests)
