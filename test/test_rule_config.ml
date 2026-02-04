open Merlint

let add_pattern pattern rules exclusions =
  Rule_config.add { Rule_config.pattern; rules } exclusions

let test_empty () =
  let exclusions = Rule_config.empty in
  Alcotest.(check bool)
    "empty exclusions don't exclude anything" false
    (Rule_config.should_exclude exclusions ~rule:"E100" ~file:"test.ml")

let test_single_pattern_single_rule () =
  let exclusions = add_pattern "test/*.ml" [ "E100" ] Rule_config.empty in
  Alcotest.(check bool)
    "matches pattern and rule" true
    (Rule_config.should_exclude exclusions ~rule:"E100" ~file:"test/foo.ml");
  Alcotest.(check bool)
    "doesn't match different rule" false
    (Rule_config.should_exclude exclusions ~rule:"E200" ~file:"test/foo.ml");
  Alcotest.(check bool)
    "doesn't match different file" false
    (Rule_config.should_exclude exclusions ~rule:"E100" ~file:"lib/foo.ml")

let test_multiple_patterns () =
  let exclusions =
    Rule_config.empty
    |> add_pattern "test/*.ml" [ "E100" ]
    |> add_pattern "lib/generated/*.ml" [ "E200"; "E300" ]
  in
  Alcotest.(check bool)
    "matches first pattern" true
    (Rule_config.should_exclude exclusions ~rule:"E100" ~file:"test/bar.ml");
  Alcotest.(check bool)
    "matches second pattern rule E200" true
    (Rule_config.should_exclude exclusions ~rule:"E200"
       ~file:"lib/generated/code.ml");
  Alcotest.(check bool)
    "matches second pattern rule E300" true
    (Rule_config.should_exclude exclusions ~rule:"E300"
       ~file:"lib/generated/code.ml");
  Alcotest.(check bool)
    "doesn't match wrong combination" false
    (Rule_config.should_exclude exclusions ~rule:"E100"
       ~file:"lib/generated/code.ml")

let test_wildcard_patterns () =
  let exclusions =
    Rule_config.empty
    |> add_pattern "**/*.test.ml" [ "E400" ]
    |> add_pattern "lib/rules/e*.ml" [ "E500" ]
  in
  Alcotest.(check bool)
    "matches recursive wildcard" true
    (Rule_config.should_exclude exclusions ~rule:"E400"
       ~file:"deep/nested/dir/file.test.ml");
  Alcotest.(check bool)
    "matches single character wildcard" true
    (Rule_config.should_exclude exclusions ~rule:"E500"
       ~file:"lib/rules/e100.ml");
  Alcotest.(check bool)
    "doesn't match non-e prefix" false
    (Rule_config.should_exclude exclusions ~rule:"E500"
       ~file:"lib/rules/rule.ml")

let test_exact_match () =
  let exclusions = add_pattern "lib/specific.ml" [ "E600" ] Rule_config.empty in
  Alcotest.(check bool)
    "matches exact file" true
    (Rule_config.should_exclude exclusions ~rule:"E600" ~file:"lib/specific.ml");
  Alcotest.(check bool)
    "doesn't match similar file" false
    (Rule_config.should_exclude exclusions ~rule:"E600" ~file:"lib/specific2.ml")

let test_prefix_patterns () =
  let exclusions = add_pattern "lib/prose*.ml" [ "E330" ] Rule_config.empty in
  Alcotest.(check bool)
    "matches prefix pattern" true
    (Rule_config.should_exclude exclusions ~rule:"E330" ~file:"lib/prose_foo.ml");
  Alcotest.(check bool)
    "matches prefix pattern without suffix" true
    (Rule_config.should_exclude exclusions ~rule:"E330" ~file:"lib/prose.ml");
  Alcotest.(check bool)
    "doesn't match different prefix" false
    (Rule_config.should_exclude exclusions ~rule:"E330" ~file:"lib/process.ml")

let test_pp () =
  let exclusions =
    Rule_config.empty
    |> add_pattern "test/*.ml" [ "E100"; "E200" ]
    |> add_pattern "lib/*.ml" [ "E300" ]
  in
  let output = Fmt.to_to_string Rule_config.pp exclusions in
  (* Just check that it produces some output without crashing *)
  Alcotest.(check bool) "pp produces output" true (String.length output > 0)

let test_equal () =
  let exclusions1 = add_pattern "*.ml" [ "E100" ] Rule_config.empty in
  let exclusions2 = add_pattern "*.ml" [ "E100" ] Rule_config.empty in
  let exclusions3 = add_pattern "*.ml" [ "E200" ] Rule_config.empty in
  Alcotest.(check bool)
    "equal exclusions are equal" true
    (Rule_config.equal exclusions1 exclusions2);
  Alcotest.(check bool)
    "different exclusions are not equal" false
    (Rule_config.equal exclusions1 exclusions3)

let suite =
  ( "rule_config",
    [
      ("empty", `Quick, test_empty);
      ("single pattern single rule", `Quick, test_single_pattern_single_rule);
      ("multiple patterns", `Quick, test_multiple_patterns);
      ("wildcard patterns", `Quick, test_wildcard_patterns);
      ("exact match", `Quick, test_exact_match);
      ("prefix patterns", `Quick, test_prefix_patterns);
      ("pp", `Quick, test_pp);
      ("equal", `Quick, test_equal);
    ] )
