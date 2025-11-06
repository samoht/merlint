open Merlint

(* Testable config using our pp and equal functions *)
let config : Config.t Alcotest.testable =
  Alcotest.testable Config.pp Config.equal

let test_default_config () =
  let config = Config.default in
  Alcotest.check Alcotest.int "max_complexity" 10 config.max_complexity;
  Alcotest.check Alcotest.int "max_function_length" 50
    config.max_function_length;
  Alcotest.check Alcotest.int "max_nesting" 4 config.max_nesting;
  Alcotest.check Alcotest.bool "require_ocamlformat_file" true
    config.require_ocamlformat_file

let test_equal () =
  let config1 = Config.default in
  let config2 = Config.default in
  let config3 = { config1 with max_complexity = 20 } in

  Alcotest.check config "same configs are equal" config1 config2;
  Alcotest.check Alcotest.bool "different configs not equal" false
    (Config.equal config1 config3)

let tests =
  [
    Alcotest.test_case "default_config" `Quick test_default_config;
    Alcotest.test_case "equal" `Quick test_equal;
  ]

let suite = ("config", tests)
