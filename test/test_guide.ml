(** Tests for Guide module *)

let test_content_structure () =
  (* Test that guide content has expected structure *)
  let content = Merlint.Guide.content in
  Alcotest.(check bool) "content not empty" true (List.length content > 0)

let test_element_types () =
  (* Test different element types *)
  let has_title = ref false in
  let has_section = ref false in
  let rec check_elements = function
    | [] -> ()
    | Merlint.Guide.Title _ :: rest -> 
        has_title := true; check_elements rest
    | Merlint.Guide.Section (_, children) :: rest ->
        has_section := true;
        check_elements children;
        check_elements rest
    | _ :: rest -> check_elements rest
  in
  check_elements Merlint.Guide.content;
  Alcotest.(check bool) "has title" true !has_title;
  Alcotest.(check bool) "has section" true !has_section

let test_rule_references () =
  (* Test that guide references some rules *)
  let rule_count = ref 0 in
  let rec count_rules = function
    | [] -> ()
    | Merlint.Guide.Rule _ :: rest ->
        incr rule_count; count_rules rest
    | Merlint.Guide.Section (_, children) :: rest ->
        count_rules children; count_rules rest
    | _ :: rest -> count_rules rest
  in
  count_rules Merlint.Guide.content;
  Alcotest.(check bool) "has rule references" true (!rule_count > 0)

let tests =
  [
    ("content_structure", `Quick, test_content_structure);
    ("element_types", `Quick, test_element_types);
    ("rule_references", `Quick, test_rule_references);
  ]

let suite = ("guide", tests)