let setup_log log_level =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level log_level;
  Logs.set_reporter (Logs_fmt.reporter ~dst:Fmt.stderr ~app:Fmt.stdout ())

let () = setup_log (Some Debug)

let () =
  let suites =
    Test_config.suite @ Test_rules_integration.suite @ Test_style_rules.suite
    @ Test_browse.suite @ Test_outline.suite @ Test_typedtree.suite
    @ Test_parsetree.suite @ Test_complexity.suite @ Test_doc.suite
    @ Test_dune.suite @ Test_format.suite @ Test_issue.suite
    @ Test_location.suite @ Test_merlin.suite @ Test_naming.suite
    @ Test_report.suite @ Test_rules.suite @ Test_style.suite
    @ Test_warning_checks.suite
    @ [ Test_underscore_binding.suite; Test_rule_filter.suite ]
  in
  Alcotest.run "merlint" suites
