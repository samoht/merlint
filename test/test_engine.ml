open Merlint

let default_config () =
  let config = Engine.default_config "/some/path" in
  Alcotest.(check string) "project root" "/some/path" config.project_root;
  (* Just verify we get a valid config *)
  Alcotest.(check bool)
    "has merlint config" true
    (config.merlint_config == Config.default)

let suite =
  [ ("engine", [ Alcotest.test_case "default config" `Quick default_config ]) ]
