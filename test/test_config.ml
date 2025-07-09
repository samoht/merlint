open Merlint

let test_default_config () =
  let config = Config.default in
  Alcotest.check Alcotest.int "max_complexity" 10 config.max_complexity;
  Alcotest.check Alcotest.int "max_function_length" 50
    config.max_function_length;
  Alcotest.check Alcotest.int "max_nesting" 3 config.max_nesting;
  Alcotest.check Alcotest.bool "require_ocamlformat_file" true
    config.require_ocamlformat_file

let test_to_complexity_config () =
  let config = Config.default in
  let complexity_config = Config.to_complexity_config config in
  Alcotest.check Alcotest.int "converted max_complexity" 10
    complexity_config.max_complexity;
  Alcotest.check Alcotest.int "converted max_function_length" 50
    complexity_config.max_function_length

let tests =
  [
    Alcotest.test_case "default_config" `Quick test_default_config;
    Alcotest.test_case "to_complexity_config" `Quick test_to_complexity_config;
  ]

let suite = [ ("config", tests) ]
