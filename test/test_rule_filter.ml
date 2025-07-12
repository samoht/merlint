open Alcotest

let test_parse_range () =
  let module RF = Merlint.Rule_filter in
  (* Test simple range *)
  match RF.parse "all-100..199" with
  | Ok filter ->
      check bool "E001 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Complexity);
      check bool "E100 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Obj_magic);
      check bool "E105 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Catch_all_exception);
      check bool "E200 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Str_module)
  | Error msg -> fail msg

let test_parse_exclusions () =
  let module RF = Merlint.Rule_filter in
  (* Test exclusion syntax *)
  match RF.parse "all-E110-E205" with
  | Ok filter ->
      check bool "E001 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Complexity);
      check bool "E110 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Silenced_warning);
      check bool "E205 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Printf_module);
      check bool "E200 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Str_module)
  | Error msg -> fail msg

let test_parse_selective () =
  let module RF = Merlint.Rule_filter in
  (* Test selective enabling *)
  match RF.parse "E300+E305" with
  | Ok filter ->
      check bool "E300 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Variant_naming);
      check bool "E305 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Module_naming);
      check bool "E001 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Complexity);
      check bool "E200 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Str_module)
  | Error msg -> fail msg

let test_parse_single () =
  let module RF = Merlint.Rule_filter in
  (* Test single rule *)
  match RF.parse "E300" with
  | Ok filter ->
      check bool "E300 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Variant_naming);
      check bool "E001 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Complexity);
      check bool "E200 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Str_module)
  | Error msg -> fail msg

let test_parse_mixed () =
  let module RF = Merlint.Rule_filter in
  (* Test mixed format *)
  match RF.parse "300..399-E320" with
  | Ok filter ->
      check bool "E300 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Variant_naming);
      check bool "E305 enabled" true
        (RF.is_enabled filter Merlint.Issue_type.Module_naming);
      check bool "E320 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Long_identifier);
      check bool "E001 disabled" false
        (RF.is_enabled filter Merlint.Issue_type.Complexity)
  | Error msg -> fail msg

let test_parse_errors () =
  let module RF = Merlint.Rule_filter in
  (* Test error cases *)
  (match RF.parse "invalid" with
  | Ok _ -> fail "Should have failed for invalid spec"
  | Error _ -> ());

  match RF.parse "E999" with
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
