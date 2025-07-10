let () =
  let suites =
    Test_config.suite @ Test_rules_integration.suite @ Test_style_rules.suite
    @ Test_browse.suite @ Test_parsetree.suite @ Test_outline.suite
    @ Test_typedtree.suite @ Test_complexity.suite @ Test_doc.suite
    @ Test_dune.suite @ Test_format.suite @ Test_issue.suite
    @ Test_location.suite @ Test_parser.suite @ Test_sexp.suite
  in
  Alcotest.run "merlint" suites
