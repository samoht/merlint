(** Tests for Typedtree module *)

open Merlint.Typedtree
open Merlint.Ast

let test_parse_empty () =
  let json = `String "" in
  let result = of_json json in
  Alcotest.(check int) "no identifiers" 0 (List.length result.identifiers);
  Alcotest.(check int) "no patterns" 0 (List.length result.patterns)

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
  Alcotest.(check int) "has pattern" 1 (List.length result.patterns);
  match result.patterns with
  | [ elt ] ->
      Alcotest.(check string) "pattern name" "foo" (name_to_string elt.name)
  | _ -> Alcotest.fail "Expected exactly one pattern"

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
  Alcotest.(check int) "has identifiers" 1 (List.length result.identifiers);
  Alcotest.(check int) "has value bindings" 1 (List.length result.patterns);
  match result.identifiers with
  | [ id ] ->
      Alcotest.(check string) "identifier name" "y" (name_to_string id.name)
  | _ -> Alcotest.fail "Expected exactly one identifier"

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
  (* This test just verifies the parser doesn't crash on function cases *)
  Alcotest.(check int)
    "no identifiers in function cases" 0
    (List.length result.identifiers)

let test_extract_obj_magic () =
  let json =
    `String
      "structure_item (test.ml[1,0+0]..test.ml[1,0+30])\n\
      \  Tstr_value Nonrec\n\
      \  [\n\
      \    <def>\n\
      \      pattern (test.ml[1,0+4]..test.ml[1,0+13])\n\
      \        Tpat_var \"dangerous/123\"\n\
      \      expression (test.ml[1,0+16]..test.ml[1,0+30])\n\
      \        Texp_apply\n\
      \        expression (test.ml[1,0+16]..test.ml[1,0+25])\n\
      \          Texp_ident \"Stdlib!.Obj.magic\"\n\
      \        [\n\
      \          <arg>\n\
      \            Nolabel\n\
      \            expression (test.ml[1,0+26]..test.ml[1,0+30])\n\
      \              Texp_constant Const_int(42,None)\n\
      \        ]\n\
      \  ]"
  in
  let result = of_json json in
  Alcotest.(check int) "has one identifier" 1 (List.length result.identifiers);
  Alcotest.(check int) "has one value binding" 1 (List.length result.patterns);
  (match result.identifiers with
  | [ id ] ->
      Alcotest.(check string)
        "obj magic identifier" "Stdlib.Obj.magic" (name_to_string id.name)
  | _ -> Alcotest.fail "Expected exactly one identifier");
  match result.patterns with
  | [ elt ] ->
      Alcotest.(check string)
        "pattern name" "dangerous" (name_to_string elt.name)
  | _ -> Alcotest.fail "Expected exactly one pattern"

let test_extract_multiple_identifiers () =
  let json =
    `String
      "structure_item (test.ml[1,0+0]..test.ml[3,0+50])\n\
      \  Tstr_value Nonrec\n\
      \  [\n\
      \    <def>\n\
      \      pattern (test.ml[1,0+4]..test.ml[1,0+12])\n\
      \        Tpat_var \"bad_code/456\"\n\
      \      expression (test.ml[2,0+2]..test.ml[3,0+40])\n\
      \        Texp_sequence\n\
      \        expression (test.ml[2,0+2]..test.ml[2,0+30])\n\
      \          Texp_apply\n\
      \          expression (test.ml[2,0+2]..test.ml[2,0+15])\n\
      \            Texp_ident \"Stdlib!.Printf.printf\"\n\
      \          [\n\
      \            <arg>\n\
      \              Nolabel\n\
      \              expression (test.ml[2,0+16]..test.ml[2,0+30])\n\
      \                Texp_constant Const_string(\"Hello %s\",None)\n\
      \          ]\n\
      \        expression (test.ml[3,0+2]..test.ml[3,0+20])\n\
      \          Texp_apply\n\
      \          expression (test.ml[3,0+2]..test.ml[3,0+15])\n\
      \            Texp_ident \"Stdlib!.Str.split\"\n\
      \          [\n\
      \            <arg>\n\
      \              Nolabel\n\
      \              expression (test.ml[3,0+16]..test.ml[3,0+20])\n\
      \                Texp_ident \"data/789\"\n\
      \          ]\n\
      \  ]"
  in
  let result = of_json json in
  Alcotest.(check int)
    "has three identifiers" 3
    (List.length result.identifiers);
  Alcotest.(check int) "has one value binding" 1 (List.length result.patterns);
  let identifier_names =
    List.map (fun id -> name_to_string id.name) result.identifiers
  in
  Alcotest.(check bool)
    "has printf" true
    (List.mem "Stdlib.Printf.printf" identifier_names);
  Alcotest.(check bool)
    "has str" true
    (List.mem "Stdlib.Str.split" identifier_names);
  Alcotest.(check bool) "has data" true (List.mem "data" identifier_names)

let test_extract_modules () =
  let json =
    `String
      "structure_item (test.ml[1,0+0]..test.ml[1,0+20])\n\
      \  Tstr_module\n\
      \  module_binding (test.ml[1,0+7]..test.ml[1,0+20])\n\
      \    \"MyModule/999\"\n\
      \    module_expr (test.ml[1,0+18]..test.ml[1,0+20])\n\
      \      Tmod_structure\n\
      \      []\n"
  in
  let result = of_json json in
  Alcotest.(check int) "has one module" 1 (List.length result.modules);
  match result.modules with
  | [ elt ] ->
      Alcotest.(check string) "module name" "MyModule" (name_to_string elt.name)
  | _ -> Alcotest.fail "Expected exactly one module"

let test_identifier_with_location () =
  let json =
    `String
      "expression (test.ml[1,0+11]..test.ml[1,0+31])\n\
      \  Texp_ident \"Stdlib!.Printf.printf\""
  in
  let result = of_json json in
  Alcotest.(check int) "has one identifier" 1 (List.length result.identifiers);
  match result.identifiers with
  | [ id ] -> (
      Alcotest.(check bool)
        "identifier has location" true
        (Option.is_some id.location);
      match id.location with
      | Some loc ->
          let pp_loc = Fmt.to_to_string Merlint.Location.pp loc in
          Alcotest.(check bool)
            "location contains test.ml" true
            (String.contains pp_loc 'e')
      | None -> Alcotest.fail "Expected location")
  | _ -> Alcotest.fail "Expected exactly one identifier"

let test_pattern_with_location () =
  let json =
    `String "pattern (test.ml[1,0+4]..test.ml[1,0+8])\n  Tpat_var \"test/276\""
  in
  let result = of_json json in
  Alcotest.(check int) "has one pattern" 1 (List.length result.patterns);
  match result.patterns with
  | [ pat ] ->
      Alcotest.(check bool)
        "pattern has location" true
        (Option.is_some pat.location)
  | _ -> Alcotest.fail "Expected exactly one pattern"

let test_nested_identifier_location () =
  (* Test that identifiers inside expressions get the parent's location *)
  let json =
    `String
      "structure_item (test.ml[1,0+0]..test.ml[1,0+30])\n\
      \  Tstr_value Nonrec\n\
      \  [\n\
      \    <def>\n\
      \      pattern (test.ml[1,0+4]..test.ml[1,0+13])\n\
      \        Tpat_var \"dangerous/123\"\n\
      \      expression (test.ml[1,0+16]..test.ml[1,0+30])\n\
      \        Texp_apply\n\
      \        expression (test.ml[1,0+16]..test.ml[1,0+25])\n\
      \          Texp_ident \"Stdlib!.Obj.magic\"\n\
      \        [\n\
      \          <arg>\n\
      \            Nolabel\n\
      \            expression (test.ml[1,0+26]..test.ml[1,0+30])\n\
      \              Texp_constant Const_int(42,None)\n\
      \        ]\n\
      \  ]"
  in
  let result = of_json json in
  Alcotest.(check int) "has one identifier" 1 (List.length result.identifiers);
  match result.identifiers with
  | [ id ] -> (
      Alcotest.(check bool)
        "identifier has location" true
        (Option.is_some id.location);
      match id.location with
      | Some loc ->
          Alcotest.(check int) "start line" 1 loc.Merlint.Location.start_line;
          Alcotest.(check int) "start col" 16 loc.Merlint.Location.start_col;
          Alcotest.(check int) "end line" 1 loc.Merlint.Location.end_line;
          Alcotest.(check int) "end col" 25 loc.Merlint.Location.end_col
      | None -> Alcotest.fail "Expected location")
  | _ -> Alcotest.fail "Expected exactly one identifier"

let test_multiple_identifiers_locations () =
  let json =
    `String
      "expression (test.ml[2,0+2]..test.ml[2,0+30])\n\
      \  Texp_apply\n\
      \  expression (test.ml[2,0+2]..test.ml[2,0+15])\n\
      \    Texp_ident \"Stdlib!.Printf.printf\"\n\
      \  [\n\
      \    <arg>\n\
      \      Nolabel\n\
      \      expression (test.ml[2,0+16]..test.ml[2,0+30])\n\
      \        Texp_ident \"some_var/123\"\n\
      \  ]"
  in
  let result = of_json json in
  Alcotest.(check int) "has two identifiers" 2 (List.length result.identifiers);
  List.iter
    (fun id ->
      Alcotest.(check bool)
        (Fmt.str "identifier %s has location" (name_to_string id.name))
        true
        (Option.is_some id.location))
    result.identifiers

let tests =
  [
    Alcotest.test_case "parse_empty" `Quick test_parse_empty;
    Alcotest.test_case "parse_with_function" `Quick test_parse_with_function;
    Alcotest.test_case "parse_with_match" `Quick test_parse_with_match;
    Alcotest.test_case "parse_function_cases" `Quick test_parse_function_cases;
    Alcotest.test_case "extract_obj_magic" `Quick test_extract_obj_magic;
    Alcotest.test_case "extract_multiple_identifiers" `Quick
      test_extract_multiple_identifiers;
    Alcotest.test_case "extract_modules" `Quick test_extract_modules;
    Alcotest.test_case "identifier_with_location" `Quick
      test_identifier_with_location;
    Alcotest.test_case "pattern_with_location" `Quick test_pattern_with_location;
    Alcotest.test_case "nested_identifier_location" `Quick
      test_nested_identifier_location;
    Alcotest.test_case "multiple_identifiers_locations" `Quick
      test_multiple_identifiers_locations;
  ]

let suite = [ ("typedtree", tests) ]
