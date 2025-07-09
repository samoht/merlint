open Merlint

let extract_location_parsetree () =
  let text = "Pexp_ident \"Obj.magic\" (bad_style.ml[2,27+16]..[2,27+25])" in
  match Style_rules.extract_location_from_parsetree text with
  | Some (line, col) ->
      Alcotest.check Alcotest.int "line" 2 line;
      Alcotest.check Alcotest.int "col" 16 col
  | None -> Alcotest.fail "Location extraction failed"

let extract_filename_parsetree () =
  let text = "Pexp_ident \"Obj.magic\" (bad_style.ml[2,27+16]..[2,27+25])" in
  let filename = Style_rules.extract_filename_from_parsetree text in
  Alcotest.check Alcotest.string "filename" "bad_style.ml" filename

let test_check_obj_magic () =
  let text = "Pexp_ident \"Obj.magic\" (bad_style.ml[2,27+16]..[2,27+25])" in
  let issues = Style_rules.check (`String text) in
  Alcotest.check Alcotest.int "issue count" 1 (List.length issues);
  match issues with
  | [ Issue.No_obj_magic { location = { file; line; col } } ] ->
      Alcotest.check Alcotest.string "file" "bad_style.ml" file;
      Alcotest.check Alcotest.int "line" 2 line;
      Alcotest.check Alcotest.int "col" 16 col
  | _ -> Alcotest.fail "Expected 1 Obj.magic issue"

let test_check_str_module () =
  let text = "Pexp_ident \"Str.split\" (uses_str.ml[2,28+20]..[2,28+29])" in
  let issues = Style_rules.check (`String text) in
  Alcotest.check Alcotest.int "issue count" 1 (List.length issues);
  match issues with
  | [ Issue.Use_str_module { location = { file; line; col } } ] ->
      Alcotest.check Alcotest.string "file" "uses_str.ml" file;
      Alcotest.check Alcotest.int "line" 2 line;
      Alcotest.check Alcotest.int "col" 20 col
  | _ -> Alcotest.fail "Expected 1 Str module issue"

let test_full_parsetree_sample () =
  let sample_text =
    {|[
  structure_item (bad_style.ml[2,27+0]..[2,27+27])
    Pstr_value Nonrec
    [
      <def>
        pattern (bad_style.ml[2,27+4]..[2,27+11])
          Ppat_var "convert" (bad_style.ml[2,27+4]..[2,27+11])
        expression (bad_style.ml[2,27+12]..[2,27+27]) ghost
          Pexp_function
          [
            Pparam_val (bad_style.ml[2,27+12]..[2,27+13])
              Nolabel
              None
              pattern (bad_style.ml[2,27+12]..[2,27+13])
                Ppat_var "x" (bad_style.ml[2,27+12]..[2,27+13])
          ]
          None
          Pfunction_body
            expression (bad_style.ml[2,27+16]..[2,27+27])
              Pexp_apply
              expression (bad_style.ml[2,27+16]..[2,27+25])
                Pexp_ident "Obj.magic" (bad_style.ml[2,27+16]..[2,27+25])
              [
                <arg>
                Nolabel
                  expression (bad_style.ml[2,27+26]..[2,27+27])
                    Pexp_ident "x" (bad_style.ml[2,27+26]..[2,27+27])
              ]
    ]
]|}
  in
  let issues = Style_rules.check (`String sample_text) in
  Alcotest.check Alcotest.bool "has issues" true (List.length issues > 0)

let tests =
  [
    Alcotest.test_case "location_extraction" `Quick
      extract_location_parsetree;
    Alcotest.test_case "filename_extraction" `Quick
      extract_filename_parsetree;
    Alcotest.test_case "obj_magic_detection" `Quick test_check_obj_magic;
    Alcotest.test_case "str_module_detection" `Quick test_check_str_module;
    Alcotest.test_case "full_parsetree" `Quick test_full_parsetree_sample;
  ]

let suite = [ ("style_rules", tests) ]
