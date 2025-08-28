open Merlint

let test_parse_empty () =
  let input = "" in
  let result = Config_parser.parse input in
  Alcotest.(check int)
    "empty input returns empty settings" 0
    (List.length result.settings);
  Alcotest.(check bool)
    "empty input returns empty exclusions" true
    (result.exclusions = Rule_config.empty)

let test_parse_settings_only () =
  let input = {|settings:
  max-complexity: 15
  max-function-length: 100
|} in
  let config = Config_parser.parse input in
  Alcotest.(check int) "settings count" 2 (List.length config.settings);
  Alcotest.(check bool)
    "has max-complexity" true
    (List.mem_assoc "max-complexity" config.settings);
  Alcotest.(check string)
    "max-complexity value" "15"
    (List.assoc "max-complexity" config.settings);
  Alcotest.(check bool)
    "no exclusions" true
    (config.exclusions = Rule_config.empty)

let test_parse_exclusions_only () =
  let input =
    {|exclusions:
  - pattern: "*.test.ml"
    rules: [E100, E200]
|}
  in
  let config = Config_parser.parse input in
  Alcotest.(check int) "no settings" 0 (List.length config.settings);
  Alcotest.(check bool)
    "has exclusions" false
    (config.exclusions = Rule_config.empty)

let test_parse_full_config () =
  let input =
    {|# Full configuration example
settings:
  max-complexity: 20
  allow-obj-magic: true

exclusions:
  - pattern: test/**/*.ml
    rules: [E400]
  - pattern: lib/generated/*.ml
    rules: [E100, E200, E300]
|}
  in
  let config = Config_parser.parse input in
  Alcotest.(check int) "settings count" 2 (List.length config.settings);
  Alcotest.(check bool)
    "has exclusions" false
    (config.exclusions = Rule_config.empty)

let test_parse_invalid_yaml () =
  let input = {|settings
  max-complexity: 10
|} in
  let config = Config_parser.parse input in
  (* Just check it doesn't crash - invalid YAML might return empty config *)
  let _ = config.settings in
  ()

let test_parse_with_comments () =
  let input =
    {|# This is a comment
settings:
  # Another comment
  max-complexity: 8  # inline comment
|}
  in
  let config = Config_parser.parse input in
  Alcotest.(check int) "settings count" 1 (List.length config.settings);
  Alcotest.(check string)
    "max-complexity value" "8"
    (List.assoc "max-complexity" config.settings)

let test_parse_file () =
  (* Create a temporary config file *)
  let temp_file = Filename.temp_file "test_config" ".merlint" in
  let content =
    {|settings:
  max-complexity: 25
exclusions:
  - pattern: "*.generated.ml"
    rules: [E001]
|}
  in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;

  let result = Config_parser.parse_file temp_file in
  Sys.remove temp_file;

  match result with
  | None -> Alcotest.fail "Should parse valid file"
  | Some config ->
      Alcotest.(check int) "settings count" 1 (List.length config.settings);
      Alcotest.(check bool)
        "has exclusions" false
        (config.exclusions = Rule_config.empty)

let suite =
  ( "config_parser",
    [
      ("parse empty", `Quick, test_parse_empty);
      ("parse settings only", `Quick, test_parse_settings_only);
      ("parse exclusions only", `Quick, test_parse_exclusions_only);
      ("parse full config", `Quick, test_parse_full_config);
      ("parse invalid yaml", `Quick, test_parse_invalid_yaml);
      ("parse with comments", `Quick, test_parse_with_comments);
      ("parse file", `Quick, test_parse_file);
    ] )
