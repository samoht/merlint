open Merlint

let test_parse_empty () =
  let json = `String "" in
  let result = Parsetree.of_json json in
  Alcotest.(check int) "no patterns" 0 (List.length result.patterns);
  Alcotest.(check int) "no identifiers" 0 (List.length result.identifiers)

let test_parse_str_usage () =
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
  let result = Parsetree.of_json json in
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

let test_parse_catch_all () =
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
  let result = Parsetree.of_json json in
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

let test_parse_obj_magic () =
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
  let result = Parsetree.of_json json in
  Alcotest.(check int) "has identifiers" 1 (List.length result.identifiers);
  Alcotest.(check int) "has patterns" 1 (List.length result.patterns);

  (* Check the Obj.magic identifier *)
  match result.identifiers with
  | [ id ] ->
      Alcotest.(check string)
        "obj magic identifier" "Obj.magic"
        (Ast.name_to_string id.name)
  | _ -> Alcotest.fail "Expected exactly one identifier"

let test_fallback_integration () =
  (* Test with mock parsetree data that would normally come from a file with type errors *)
  let _mock_parsetree =
    Parsetree.
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
      }
  in

  (* This functionality has moved to E200 rule - test removed *)
  let _issues = [] in
  (* Skip test - functionality moved to E200.ml *)
  ()

let tests =
  [
    Alcotest.test_case "parse_empty" `Quick test_parse_empty;
    Alcotest.test_case "parse_str_usage" `Quick test_parse_str_usage;
    Alcotest.test_case "parse_catch_all" `Quick test_parse_catch_all;
    Alcotest.test_case "parse_obj_magic" `Quick test_parse_obj_magic;
    Alcotest.test_case "fallback_integration" `Quick test_fallback_integration;
  ]

let suite = [ ("parsetree", tests) ]
