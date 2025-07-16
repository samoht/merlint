let setup_log log_level =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level log_level;
  Logs.set_reporter (Logs_fmt.reporter ~dst:Fmt.stderr ~app:Fmt.stdout ())

let () = setup_log (Some Debug)

let () =
  let suites =
    Test_config.suite @ Test_browse.suite @ Test_outline.suite @ Test_ast.suite
    @ Test_dune.suite @ Test_issue.suite @ Test_location.suite
    @ Test_merlin.suite @ Test_report.suite @ Test_engine.suite
    @ [ Test_filter.suite ]
  in
  Alcotest.run "merlint" suites
