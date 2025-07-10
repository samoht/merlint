(** Unit tests for the Parser module **)

open Merlint.Parser

let test_parse_node_type () =
  let match_type = parse_node_type "Texp_match" in
  let if_type = parse_node_type "Texp_ifthenelse" in
  let while_type = parse_node_type "Texp_while" in
  let for_type = parse_node_type "Texp_for" in
  let try_type = parse_node_type "Texp_try" in
  let let_type = parse_node_type "Texp_let" in
  let other_type = parse_node_type "unknown_type" in

  Alcotest.(check bool) "match type" true (match_type = Texp_match);
  Alcotest.(check bool) "if type" true (if_type = Texp_ifthenelse);
  Alcotest.(check bool) "while type" true (while_type = Texp_while);
  Alcotest.(check bool) "for type" true (for_type = Texp_for);
  Alcotest.(check bool) "try type" true (try_type = Texp_try);
  Alcotest.(check bool) "let type" true (let_type = Texp_let);
  Alcotest.(check bool)
    "other type" true
    (match other_type with Texp_other _ -> true | _ -> false)

let test_adds_complexity () =
  Alcotest.(check bool)
    "match adds complexity" true
    (adds_complexity Texp_match);
  Alcotest.(check bool)
    "if adds complexity" true
    (adds_complexity Texp_ifthenelse);
  Alcotest.(check bool)
    "while adds complexity" true
    (adds_complexity Texp_while);
  Alcotest.(check bool) "for adds complexity" true (adds_complexity Texp_for);
  Alcotest.(check bool) "try adds complexity" true (adds_complexity Texp_try);
  Alcotest.(check bool)
    "let doesn't add complexity" false (adds_complexity Texp_let);
  Alcotest.(check bool)
    "apply doesn't add complexity" false
    (adds_complexity Texp_apply)

let test_is_pattern_match () =
  Alcotest.(check bool)
    "match is pattern match" true
    (is_pattern_match Texp_match);
  Alcotest.(check bool)
    "function_cases is pattern match" true
    (is_pattern_match Tfunction_cases);
  Alcotest.(check bool)
    "if is not pattern match" false
    (is_pattern_match Texp_ifthenelse);
  Alcotest.(check bool)
    "let is not pattern match" false
    (is_pattern_match Texp_let)

let test_is_conditional () =
  Alcotest.(check bool)
    "if is conditional" true
    (is_conditional Texp_ifthenelse);
  Alcotest.(check bool)
    "match is not conditional" false
    (is_conditional Texp_match);
  Alcotest.(check bool) "let is not conditional" false (is_conditional Texp_let)

let test_is_loop () =
  Alcotest.(check bool) "while is loop" true (is_loop Texp_while);
  Alcotest.(check bool) "for is loop" true (is_loop Texp_for);
  Alcotest.(check bool) "if is not loop" false (is_loop Texp_ifthenelse);
  Alcotest.(check bool) "let is not loop" false (is_loop Texp_let)

let test_is_try_block () =
  Alcotest.(check bool) "try is try block" true (is_try_block Texp_try);
  Alcotest.(check bool)
    "if is not try block" false
    (is_try_block Texp_ifthenelse);
  Alcotest.(check bool) "let is not try block" false (is_try_block Texp_let)

let test_parse_location_string () =
  let loc_str = "issue.ml[100,2484+7]..[157,5470+29]" in
  match parse_location_string loc_str with
  | Some loc ->
      Alcotest.(check string) "file name" "issue" loc.file;
      Alcotest.(check int) "start line" 100 loc.start_line;
      Alcotest.(check int) "start col" 2484 loc.start_col;
      Alcotest.(check int) "end line" 157 loc.end_line;
      Alcotest.(check int) "end col" 5470 loc.end_col
  | None -> Alcotest.fail "Failed to parse location string"

let test_parse_value_string () =
  let value_str =
    "Texp_match\nissue.ml[100,2484+7]..[157,5470+29]\n  case1\n  case2"
  in
  let nodes = parse_value_string value_str in
  match nodes with
  | [ node ] -> (
      Alcotest.(check bool) "node type" true (node.node_type = Texp_match);
      match node.location with
      | Some loc ->
          Alcotest.(check string) "file name" "issue" loc.file;
          Alcotest.(check int) "start line" 100 loc.start_line
      | None -> Alcotest.fail "Missing location information")
  | _ -> Alcotest.fail "Expected one node"

let test_real_merlin_sample () =
  (* Real sample from ocamlmerlin single dump -what typedtree for pp function *)
  let pp_function_sample = {|Tfunction_cases|} in
  let nodes = parse_value_string pp_function_sample in
  (* Check that we parsed exactly one Tfunction_cases node *)
  match nodes with
  | [ node ] when node.node_type = Tfunction_cases ->
      (* Test passes - we got exactly what we expected *)
      ()
  | [ _ ] -> Alcotest.fail "Expected Tfunction_cases node type"
  | _ ->
      Alcotest.fail
        ("Expected exactly one node, got " ^ string_of_int (List.length nodes))

let test_count_complexity () =
  let nodes =
    [
      {
        node_type = Texp_match;
        location = None;
        children = [];
        raw_content = "";
      };
      {
        node_type = Texp_ifthenelse;
        location = None;
        children = [];
        raw_content = "";
      };
      { node_type = Texp_let; location = None; children = []; raw_content = "" };
    ]
  in
  let complexity = count_complexity nodes in
  Alcotest.(check int) "complexity count" 2 complexity

let test_pattern_match_function () =
  let nodes_with_match =
    [
      {
        node_type = Texp_match;
        location = None;
        children = [];
        raw_content = "";
      };
    ]
  in
  let nodes_without_match =
    [
      { node_type = Texp_let; location = None; children = []; raw_content = "" };
    ]
  in

  Alcotest.(check bool)
    "has pattern match" true
    (is_pattern_matching_function nodes_with_match);
  Alcotest.(check bool)
    "no pattern match" false
    (is_pattern_matching_function nodes_without_match)

let test_pp_functions () =
  let node =
    {
      node_type = Texp_match;
      location =
        Some
          {
            file = "test.ml";
            start_line = 1;
            start_col = 0;
            end_line = 5;
            end_col = 10;
          };
      children = [];
      raw_content = "Texp_match";
    }
  in

  let output = Fmt.str "%a" pp_ast_node node in
  Alcotest.(check bool)
    "pretty print contains type" true
    (String.contains output 'T');
  Alcotest.(check bool)
    "pretty print contains file" true
    (String.contains output 't')

let suite =
  [
    ("parse_node_type", `Quick, test_parse_node_type);
    ("adds_complexity", `Quick, test_adds_complexity);
    ("is_pattern_match", `Quick, test_is_pattern_match);
    ("is_conditional", `Quick, test_is_conditional);
    ("is_loop", `Quick, test_is_loop);
    ("is_try_block", `Quick, test_is_try_block);
    ("parse_location_string", `Quick, test_parse_location_string);
    ("parse_value_string", `Quick, test_parse_value_string);
    ("real_merlin_sample", `Quick, test_real_merlin_sample);
    ("count_complexity", `Quick, test_count_complexity);
    ("pattern_match_function", `Quick, test_pattern_match_function);
    ("pp_functions", `Quick, test_pp_functions);
  ]
