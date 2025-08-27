let setup_log log_level =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level log_level;
  Logs.set_reporter (Logs_fmt.reporter ~dst:Fmt.stderr ~app:Fmt.stdout ())

let () = setup_log (Some Debug)

let () =
  let suites =
    [
      Test_config.suite;
      Test_project.suite;
      Test_outline.suite;
      Test_ast.suite;
      Test_dump.suite;
      Test_dune.suite;
      Test_issue.suite;
      Test_location.suite;
      Test_merlin.suite;
      Test_report.suite;
      Test_engine.suite;
      Test_naming.suite;
      Test_filter.suite;
      Test_docs.suite;
      Test_command.suite;
      Test_context.suite;
      Test_data.suite;
      Test_example.suite;
      Test_file.suite;
      Test_guide.suite;
      Test_profiling.suite;
      Test_rule.suite;
    ]
  in
  Alcotest.run "merlint" suites
