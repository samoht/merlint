let () =
  let suites =
    Test_config.suite @ Test_rules_integration.suite @ Test_style_rules.suite
    @ Test_browse.suite @ Test_parsetree.suite @ Test_outline.suite
    @ Test_typedtree.suite @ Test_complexity.suite @ Test_doc.suite
    @ Test_dune.suite @ Test_format.suite @ Test_issue.suite
    @ Test_location.suite
    (* @ Test_parser.suite @ Test_sexp.suite -- These modules don't exist *)
    @ Test_merlin.suite
    @ Test_naming.suite @ Test_report.suite @ Test_rules.suite
    @ Test_style.suite @ Test_warning_checks.suite
  in
  Alcotest.run "merlint" suites
