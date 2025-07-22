(** Tests for Data module *)

let test_all_rules_count () =
  (* Test that we have the expected number of rules *)
  let rule_count = List.length Merlint.Data.all_rules in
  Alcotest.(check bool) "has rules" true (rule_count > 0);
  Alcotest.(check bool) "reasonable count" true (rule_count < 100)

let test_rule_codes_unique () =
  (* Test that all rule codes are unique *)
  let codes = List.map Merlint.Rule.code Merlint.Data.all_rules in
  let unique_codes = List.sort_uniq String.compare codes in
  Alcotest.(check int)
    "all codes unique" (List.length codes) (List.length unique_codes)

let test_rule_categories () =
  (* Test that rules have valid categories *)
  let categories =
    List.map (fun r -> Merlint.Rule.category r) Merlint.Data.all_rules
  in
  List.iter
    (fun cat ->
      let name = Merlint.Rule.category_name cat in
      Alcotest.(check bool) "category has name" true (String.length name > 0))
    categories

let test_rule_codes () =
  (* Test that rules have valid codes *)
  let rules = Merlint.Data.all_rules in
  List.iter
    (fun rule ->
      let code = Merlint.Rule.code rule in
      Alcotest.(check bool)
        "code starts with E" true
        (String.length code > 0 && code.[0] = 'E'))
    rules

let tests =
  [
    ("all_rules_count", `Quick, test_all_rules_count);
    ("rule_codes_unique", `Quick, test_rule_codes_unique);
    ("rule_categories", `Quick, test_rule_categories);
    ("rule_codes", `Quick, test_rule_codes);
  ]

let suite = ("data", tests)
