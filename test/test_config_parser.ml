open Merlint

let test_parse_empty () =
  let input = "" in
  let result = Config_parser.parse input in
  Alcotest.(check int)
    "empty input returns empty settings" 0
    (List.length result.settings);
  Alcotest.(check bool)
    "empty input returns empty exclusions" true
    (Rule_config.equal result.exclusions Rule_config.empty)

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
    (Rule_config.equal config.exclusions Rule_config.empty)

let test_parse_exclusions_only () =
  let input = {|[[rules]]
files = "*.test.ml"
exclude = ["E100", "E200"]
|} in
  let config = Config_parser.parse input in
  Alcotest.(check int) "no settings" 0 (List.length config.settings);
  Alcotest.(check bool)
    "has exclusions" false
    (Rule_config.equal config.exclusions Rule_config.empty)

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
    (Rule_config.equal config.exclusions Rule_config.empty)

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
        (Rule_config.equal config.exclusions Rule_config.empty)

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
    (Re.execp Re.(compile (str "create_table")) value);
  Alcotest.(check bool)
    "value preserves cipher name" true
    (Re.execp Re.(compile (str "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384")) value)

let test_parse_files_list () =
  (* [files] accepts either a single string or a list of strings; the
     list form is what 50-file CSS-shaped libraries use to avoid
     dragging in a wider [lib/*.ml*] glob. *)
  let input =
    {|[[rules]]
files = ["lib/color.ml*", "lib/margin.ml*", "lib/padding.ml*"]
exclude = ["E330"]
|}
  in
  let config = Config_parser.parse input in
  Alcotest.(check bool)
    "list form parses to non-empty exclusions" false
    (Rule_config.equal config.exclusions Rule_config.empty);
  let pp = Fmt.str "%a" Rule_config.pp config.exclusions in
  let contains needle = Re.execp Re.(compile (str needle)) pp in
  Alcotest.(check bool) "first file expanded" true (contains "lib/color.ml*");
  Alcotest.(check bool) "second file expanded" true (contains "lib/margin.ml*");
  Alcotest.(check bool) "third file expanded" true (contains "lib/padding.ml*")

let test_parse_files_missing () =
  let input = {|[[rules]]
exclude = ["E100"]
|} in
  match Config_parser.parse input with
  | _ -> Alcotest.fail "expected Failure on missing files"
  | exception Failure msg ->
      Alcotest.(check bool)
        "error mentions missing files" true
        (Re.execp Re.(compile (str "missing 'files'")) msg)

let test_parse_files_wrong_type () =
  let input = {|[[rules]]
files = 42
exclude = ["E100"]
|} in
  match Config_parser.parse input with
  | _ -> Alcotest.fail "expected Failure on non-string non-list files"
  | exception Failure _ -> ()

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
      ("parse files list", `Quick, test_parse_files_list);
      ("parse files missing", `Quick, test_parse_files_missing);
      ("parse files wrong type", `Quick, test_parse_files_wrong_type);
    ] )
