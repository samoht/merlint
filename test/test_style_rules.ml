open Merlint

let extract_location_typedtree () =
  let text = "Texp_ident \"Obj.magic\" (bad_style.ml[2,27+16]..[2,27+25])" in
  match Style.extract_location_from_parsetree text with
  | Some (line, col) ->
      Alcotest.check Alcotest.int "line" 2 line;
      Alcotest.check Alcotest.int "col" 16 col
  | None -> Alcotest.fail "Location extraction failed"

let extract_filename_typedtree () =
  let text = "Texp_ident \"Obj.magic\" (bad_style.ml[2,27+16]..[2,27+25])" in
  let filename = Style.extract_filename_from_parsetree text in
  Alcotest.check Alcotest.string "filename" "bad_style.ml" filename

let test_check_obj_magic () =
  let text =
    {|expression (bad_style.ml[2,27+16]..bad_style.ml[2,27+25])
  Texp_ident "Stdlib!.Obj.magic"|}
  in
  let typedtree = Typedtree.of_json (`String text) in
  let issues = Style.check typedtree in
  Alcotest.check Alcotest.int "issue count" 1 (List.length issues);
  match issues with
  | [ Issue.No_obj_magic { location = { file; start_line; start_col; _ } } ] ->
      Alcotest.check Alcotest.string "file" "bad_style.ml" file;
      Alcotest.check Alcotest.int "line" 2 start_line;
      Alcotest.check Alcotest.int "col" 16 start_col
  | _ -> Alcotest.fail "Expected 1 Obj module issue"

let test_check_str_module () =
  let text =
    {|expression (uses_str.ml[2,28+20]..uses_str.ml[2,28+29])
  Texp_ident "Stdlib!.Str.split"|}
  in
  let typedtree = Typedtree.of_json (`String text) in
  let issues = Style.check typedtree in
  Alcotest.check Alcotest.int "issue count" 1 (List.length issues);
  match issues with
  | [ Issue.Use_str_module { location = { file; start_line; start_col; _ } } ]
    ->
      Alcotest.check Alcotest.string "file" "uses_str.ml" file;
      Alcotest.check Alcotest.int "line" 2 start_line;
      Alcotest.check Alcotest.int "col" 20 start_col
  | _ -> Alcotest.fail "Expected 1 Str module issue"

let test_full_typedtree_sample () =
  let sample_text =
    {|structure_item (bad_style.ml[2,27+0]..bad_style.ml[2,27+27])
  Tstr_value Nonrec
  [
    <def>
      pattern (bad_style.ml[2,27+4]..bad_style.ml[2,27+11])
        Tpat_var "convert/123"
      expression (bad_style.ml[2,27+16]..bad_style.ml[2,27+25])
        Texp_ident "Stdlib!.Obj.magic"
  ]|}
  in
  let typedtree = Typedtree.of_json (`String sample_text) in
  let issues = Style.check typedtree in
  Alcotest.check Alcotest.bool "has issues" true (List.length issues > 0)

let tests =
  [
    Alcotest.test_case "location_extraction" `Quick extract_location_typedtree;
    Alcotest.test_case "filename_extraction" `Quick extract_filename_typedtree;
    Alcotest.test_case "obj_magic_detection" `Quick test_check_obj_magic;
    Alcotest.test_case "str_module_detection" `Quick test_check_str_module;
    Alcotest.test_case "full_typedtree" `Quick test_full_typedtree_sample;
  ]

let suite = [ ("style_rules", tests) ]
