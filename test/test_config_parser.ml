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
  let input = {|max-complexity = 15
max-function-length = 100
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
  let input = {|[[rules]]
files = "*.test.ml"
exclude = ["E100", "E200"]
|} in
  let config = Config_parser.parse input in
  Alcotest.(check int) "no settings" 0 (List.length config.settings);
  Alcotest.(check bool)
    "has exclusions" false
    (config.exclusions = Rule_config.empty)

let test_parse_full_config () =
  let input =
    {|# Full configuration example
max-complexity = 20
allow-obj-magic = true

[[rules]]
files = "test/**/*.ml"
exclude = ["E400"]

[[rules]]
files = "lib/generated/*.ml"
exclude = ["E100", "E200", "E300"]
|}
  in
  let config = Config_parser.parse input in
  Alcotest.(check int) "settings count" 2 (List.length config.settings);
  Alcotest.(check bool)
    "has exclusions" false
    (config.exclusions = Rule_config.empty)

let test_parse_invalid_toml () =
  let input = {|max-complexity 10
|} in
  match Config_parser.parse input with
  | _ -> Alcotest.fail "expected Failure on malformed TOML"
  | exception Failure msg ->
      Alcotest.(check bool)
        "error is from merlint config" true
        (let prefix = "merlint config:" in
         String.length msg >= String.length prefix
         && String.sub msg 0 (String.length prefix) = prefix)

let test_parse_with_comments () =
  let input =
    {|# This is a comment
# Another comment
max-complexity = 8  # inline comment
|}
  in
  let config = Config_parser.parse input in
  Alcotest.(check int) "settings count" 1 (List.length config.settings);
  Alcotest.(check string)
    "max-complexity value" "8"
    (List.assoc "max-complexity" config.settings)

let test_parse_file () =
  let temp_file = Filename.temp_file "test_config" ".toml" in
  let content =
    {|max-complexity = 25

[[rules]]
files = "*.generated.ml"
exclude = ["E001"]
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

let test_parse_allowed_words_multiline () =
  (* Multi-line array values must round-trip correctly. *)
  let input =
    {|allowed_words = [
  "create_table",
  "EdDSA",
  "ECDSA",
  "SHA",
  "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384",
]
|}
  in
  let config = Config_parser.parse input in
  Alcotest.(check int) "settings count" 1 (List.length config.settings);
  let value = List.assoc "allowed_words" config.settings in
  Alcotest.(check bool)
    "value preserves create_table" true
    (let needle = "create_table" in
     let n = String.length value and k = String.length needle in
     let rec loop i =
       if i + k > n then false
       else if String.sub value i k = needle then true
       else loop (i + 1)
     in
     loop 0);
  Alcotest.(check bool)
    "value preserves cipher name" true
    (let needle = "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384" in
     let n = String.length value and k = String.length needle in
     let rec loop i =
       if i + k > n then false
       else if String.sub value i k = needle then true
       else loop (i + 1)
     in
     loop 0)

let suite =
  ( "config_parser",
    [
      ("parse empty", `Quick, test_parse_empty);
      ("parse settings only", `Quick, test_parse_settings_only);
      ("parse exclusions only", `Quick, test_parse_exclusions_only);
      ("parse full config", `Quick, test_parse_full_config);
      ("parse invalid toml", `Quick, test_parse_invalid_toml);
      ("parse with comments", `Quick, test_parse_with_comments);
      ("parse file", `Quick, test_parse_file);
      ("parse multi-line array", `Quick, test_parse_allowed_words_multiline);
    ] )
