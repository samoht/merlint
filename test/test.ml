let () =
  let suites =
    Test_config.suite @ Test_rules_integration.suite @ Test_style_rules.suite
    @ Test_browse.suite @ Test_parsetree.suite @ Test_outline.suite
    @ Test_typedtree.suite
  in
  Alcotest.run "merlint" suites
