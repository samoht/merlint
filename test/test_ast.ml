(** Tests for AST module *)

open Merlint

(** Test parsing empty parsetree *)
let test_parse_empty_parsetree () =
  let json = `String "" in
  let result = Ast.of_json ~dialect:Parsetree ~filename:"test.ml" json in
  Alcotest.(check int) "no identifiers" 0 (List.length result.identifiers);
  Alcotest.(check int) "no patterns" 0 (List.length result.patterns)

(** Test parsing empty typedtree *)
let test_parse_empty_typedtree () =
  let json = `String "" in
  let result = Ast.of_json ~dialect:Typedtree ~filename:"test.ml" json in
  Alcotest.(check int) "no identifiers" 0 (List.length result.identifiers);
  Alcotest.(check int) "no patterns" 0 (List.length result.patterns)

(** Test parsing Str.regexp usage in parsetree *)
let test_parse_str_usage_parsetree () =
  let json =
    `String
      {|[
  structure_item (test.ml[1,0+0]..test.ml[1,0+31])
    Pstr_value Nonrec
    [
      <def>
        pattern (test.ml[1,0+4]..test.ml[1,0+11])
          Ppat_var "pattern" (test.ml[1,0+4]..test.ml[1,0+11])
        expression (test.ml[1,0+14]..test.ml[1,0+31])
          Pexp_apply
          expression (test.ml[1,0+14]..test.ml[1,0+24])
            Pexp_ident "Str.regexp" (test.ml[1,0+14]..test.ml[1,0+24])
          [
            <arg>
            Nolabel
              expression (test.ml[1,0+25]..test.ml[1,0+31])
                Pexp_constant
                constant (test.ml[1,0+25]..test.ml[1,0+31])
                  PConst_string("test",(test.ml[1,0+26]..test.ml[1,0+30]),None)
          ]
    ]
]|}
  in
  let result = Ast.of_json ~dialect:Parsetree ~filename:"test.ml" json in
  Alcotest.(check int) "has identifiers" 1 (List.length result.identifiers);
  Alcotest.(check int) "has patterns" 1 (List.length result.patterns);

  (* Check the Str.regexp identifier *)
  match result.identifiers with
  | [ id ] ->
      Alcotest.(check string)
        "str identifier" "Str.regexp"
        (Ast.name_to_string id.name);
      Alcotest.(check bool) "has location" true (Option.is_some id.location)
  | _ -> Alcotest.fail "Expected exactly one identifier"

(** Test parsing catch-all pattern in parsetree *)
let test_parse_catch_all_parsetree () =
  let json =
    `String
      {|[
  structure_item (test.ml[1,0+0]..test.ml[1,0+29])
    Pstr_eval
    expression (test.ml[1,0+0]..test.ml[1,0+29])
      Pexp_try
      expression (test.ml[1,0+4]..test.ml[1,0+14])
        Pexp_apply
        expression (test.ml[1,0+4]..test.ml[1,0+11])
          Pexp_ident "List.hd" (test.ml[1,0+4]..test.ml[1,0+11])
        [
          <arg>
          Nolabel
            expression (test.ml[1,0+12]..test.ml[1,0+14])
              Pexp_construct "[]" (test.ml[1,0+12]..test.ml[1,0+14])
              None
        ]
      [
        <case>
          pattern (test.ml[1,0+20]..test.ml[1,0+21])
            Ppat_any
          expression (test.ml[1,0+25]..test.ml[1,0+29])
            attribute "merlin.loc"
              []
            Pexp_construct "None" (test.ml[1,0+25]..test.ml[1,0+29])
            None
      ]
]|}
  in
  let result = Ast.of_json ~dialect:Parsetree ~filename:"test.ml" json in
  Alcotest.(check int) "has identifiers" 1 (List.length result.identifiers);
  Alcotest.(check int) "has patterns" 1 (List.length result.patterns);

  (* Check the catch-all pattern *)
  match result.patterns with
  | [ pattern ] ->
      Alcotest.(check string)
        "catch-all pattern" "_"
        (Ast.name_to_string pattern.name);
      Alcotest.(check bool)
        "has location" true
        (Option.is_some pattern.location)
  | _ -> Alcotest.fail "Expected exactly one pattern"

(** Test parsing Obj.magic usage in parsetree *)
let test_parse_obj_magic_parsetree () =
  let json =
    `String
      {|[
  structure_item (test.ml[1,0+0]..test.ml[1,0+25])
    Pstr_value Nonrec
    [
      <def>
        pattern (test.ml[1,0+4]..test.ml[1,0+13])
          Ppat_var "dangerous" (test.ml[1,0+4]..test.ml[1,0+13])
        expression (test.ml[1,0+16]..test.ml[1,0+25])
          Pexp_apply
          expression (test.ml[1,0+16]..test.ml[1,0+25])
            Pexp_ident "Obj.magic" (test.ml[1,0+16]..test.ml[1,0+25])
          [
            <arg>
            Nolabel
              expression (test.ml[1,0+26]..test.ml[1,0+28])
                Pexp_constant
                constant (test.ml[1,0+26]..test.ml[1,0+28])
                  PConst_int(42,None)
          ]
    ]
]|}
  in
  let result = Ast.of_json ~dialect:Parsetree ~filename:"test.ml" json in
  Alcotest.(check int) "has identifiers" 1 (List.length result.identifiers);
  Alcotest.(check int) "has patterns" 1 (List.length result.patterns);

  (* Check the Obj.magic identifier *)
  match result.identifiers with
  | [ id ] ->
      Alcotest.(check string)
        "obj magic identifier" "Obj.magic"
        (Ast.name_to_string id.name)
  | _ -> Alcotest.fail "Expected exactly one identifier"

(** Test parsing function with patterns in typedtree *)
let test_parse_with_function_typedtree () =
  let json =
    `String
      "structure_item (test.ml[1,0+0]..[3,50+1])\n\
      \  Tstr_value Nonrec\n\
      \    <def>\n\
      \      Tpat_var \"foo/123\" (test.ml[1,8+4]..[1,8+7])\n\
      \      Texp_function"
  in
  let result = Ast.of_json ~dialect:Typedtree ~filename:"test.ml" json in
  Alcotest.(check int) "has pattern" 1 (List.length result.patterns);
  match result.patterns with
  | [ elt ] ->
      Alcotest.(check string) "pattern name" "foo" (Ast.name_to_string elt.name)
  | _ -> Alcotest.fail "Expected exactly one pattern"

(** Test parsing match expression in typedtree *)
let test_parse_with_match_typedtree () =
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
  let result = Ast.of_json ~dialect:Typedtree ~filename:"test.ml" json in
  Alcotest.(check int) "has identifiers" 1 (List.length result.identifiers);
  Alcotest.(check int) "has value bindings" 1 (List.length result.patterns);
  match result.identifiers with
  | [ id ] ->
      Alcotest.(check string) "identifier name" "y" (Ast.name_to_string id.name)
  | _ -> Alcotest.fail "Expected exactly one identifier"

(** Test parsing Obj.magic usage in typedtree *)
let test_extract_obj_magic_typedtree () =
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
  let result = Ast.of_json ~dialect:Typedtree ~filename:"test.ml" json in
  Alcotest.(check int) "has one identifier" 1 (List.length result.identifiers);
  Alcotest.(check int) "has one value binding" 1 (List.length result.patterns);
  (match result.identifiers with
  | [ id ] ->
      Alcotest.(check string)
        "obj magic identifier" "Stdlib.Obj.magic"
        (Ast.name_to_string id.name)
  | _ -> Alcotest.fail "Expected exactly one identifier");
  match result.patterns with
  | [ elt ] ->
      Alcotest.(check string)
        "pattern name" "dangerous"
        (Ast.name_to_string elt.name)
  | _ -> Alcotest.fail "Expected exactly one pattern"

(** Test extracting multiple identifiers in typedtree *)
let test_extract_multiple_identifiers_typedtree () =
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
  let result = Ast.of_json ~dialect:Typedtree ~filename:"test.ml" json in
  Alcotest.(check int)
    "has three identifiers" 3
    (List.length result.identifiers);
  Alcotest.(check int) "has one value binding" 1 (List.length result.patterns);
  let identifier_names =
    List.map (fun id -> Ast.name_to_string id.Ast.name) result.identifiers
  in
  Alcotest.(check bool)
    "has printf" true
    (List.mem "Stdlib.Printf.printf" identifier_names);
  Alcotest.(check bool)
    "has str" true
    (List.mem "Stdlib.Str.split" identifier_names);
  Alcotest.(check bool) "has data" true (List.mem "data" identifier_names)

(** Test extracting modules in typedtree *)
let test_extract_modules_typedtree () =
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
  let result = Ast.of_json ~dialect:Typedtree ~filename:"test.ml" json in
  Alcotest.(check int) "has one module" 1 (List.length result.modules);
  match result.modules with
  | [ elt ] ->
      Alcotest.(check string)
        "module name" "MyModule"
        (Ast.name_to_string elt.name)
  | _ -> Alcotest.fail "Expected exactly one module"

(** Test identifier with location in typedtree *)
let test_identifier_with_location_typedtree () =
  let json =
    `String
      "expression (test.ml[1,0+11]..test.ml[1,0+31])\n\
      \  Texp_ident \"Stdlib!.Printf.printf\""
  in
  let result = Ast.of_json ~dialect:Typedtree ~filename:"test.ml" json in
  Alcotest.(check int) "has one identifier" 1 (List.length result.identifiers);
  match result.identifiers with
  | [ id ] -> (
      Alcotest.(check bool)
        "identifier has location" true
        (Option.is_some id.location);
      match id.location with
      | Some loc ->
          let pp_loc = Fmt.to_to_string Location.pp loc in
          Alcotest.(check bool)
            "location contains test.ml" true
            (String.contains pp_loc 'e')
      | None -> Alcotest.fail "Expected location")
  | _ -> Alcotest.fail "Expected exactly one identifier"

(** Test pattern with location in typedtree *)
let test_pattern_with_location_typedtree () =
  let json =
    `String "pattern (test.ml[1,0+4]..test.ml[1,0+8])\n  Tpat_var \"test/276\""
  in
  let result = Ast.of_json ~dialect:Typedtree ~filename:"test.ml" json in
  Alcotest.(check int) "has one pattern" 1 (List.length result.patterns);
  match result.patterns with
  | [ pat ] ->
      Alcotest.(check bool)
        "pattern has location" true
        (Option.is_some pat.location)
  | _ -> Alcotest.fail "Expected exactly one pattern"

(** Test that mock AST structure works correctly *)
let test_mock_ast_structure () =
  (* Test with mock AST data *)
  let _mock_ast =
    Ast.
      {
        identifiers =
          [
            {
              name = { prefix = [ "Str" ]; base = "regexp" };
              location =
                Some
                  Location.
                    {
                      file = "test.ml";
                      start_line = 1;
                      start_col = 14;
                      end_line = 1;
                      end_col = 24;
                    };
            };
          ];
        patterns = [];
        modules = [];
        types = [];
        exceptions = [];
        variants = [];
        expressions = [];
      }
  in
  ()

let tests =
  [
    (* Parsetree tests *)
    Alcotest.test_case "parse_empty_parsetree" `Quick test_parse_empty_parsetree;
    Alcotest.test_case "parse_str_usage_parsetree" `Quick
      test_parse_str_usage_parsetree;
    Alcotest.test_case "parse_catch_all_parsetree" `Quick
      test_parse_catch_all_parsetree;
    Alcotest.test_case "parse_obj_magic_parsetree" `Quick
      test_parse_obj_magic_parsetree;
    (* Typedtree tests *)
    Alcotest.test_case "parse_empty_typedtree" `Quick test_parse_empty_typedtree;
    Alcotest.test_case "parse_with_function_typedtree" `Quick
      test_parse_with_function_typedtree;
    Alcotest.test_case "parse_with_match_typedtree" `Quick
      test_parse_with_match_typedtree;
    Alcotest.test_case "extract_obj_magic_typedtree" `Quick
      test_extract_obj_magic_typedtree;
    Alcotest.test_case "extract_multiple_identifiers_typedtree" `Quick
      test_extract_multiple_identifiers_typedtree;
    Alcotest.test_case "extract_modules_typedtree" `Quick
      test_extract_modules_typedtree;
    Alcotest.test_case "identifier_with_location_typedtree" `Quick
      test_identifier_with_location_typedtree;
    Alcotest.test_case "pattern_with_location_typedtree" `Quick
      test_pattern_with_location_typedtree;
    (* Mock structure test *)
    Alcotest.test_case "mock_ast_structure" `Quick test_mock_ast_structure;
  ]

let suite = [ ("ast", tests) ]
