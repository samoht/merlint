let () =
  let suites =
    Test_config.suite @ Test_rules_integration.suite @ Test_style_rules.suite
  in
  Alcotest.run "merlint" suites
