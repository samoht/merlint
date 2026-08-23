let setup_log log_level =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level log_level;
  let report src level ~over k msgf =
    let app = (Alcotest_engine.Formatters.get_stdout () :> Format.formatter) in
    let dst = (Alcotest_engine.Formatters.get_stderr () :> Format.formatter) in
    let reporter = Logs_fmt.reporter ~app ~dst () in
    reporter.Logs.report src level ~over k msgf
  in
  Logs.set_reporter { Logs.report }

let () = setup_log (Some Debug)

(* Suites here build a synthetic dune project in a temp directory and put its
   artefacts where dune puts them, under the project's own [_build]. An absolute
   [DUNE_BUILD_DIR] names one tree for every project at once -- the build
   directory of the run executing these tests -- and artefact lookup honours it
   for whatever root it is asked about, so the fixtures get looked for in a tree
   they were never written to. The relative form says the same thing dune's
   default does -- resolve [_build] against each project's own root -- so pin
   that for the process. An empty value would not do: dune refuses it outright,
   and the suites that shell out to dune need it to keep meaning something. *)
let () = Unix.putenv "DUNE_BUILD_DIR" "_build"

let () =
  let suites =
    [
      Test_categories.suite;
      Test_file_kind.suite;
      Test_config.suite;
      Test_analysis.suite;
      Test_config_parser.suite;
      Test_rule_config.suite;
      Test_project.suite;
      Test_worktree.suite;
      Test_build.suite;
      Test_issue.suite;
      Test_location.suite;
      Test_report.suite;
      Test_engine.suite;
      Test_naming.suite;
      Test_filter.suite;
      Test_docs.suite;
      Test_doc.suite;
      Test_command.suite;
      Test_context.suite;
      Test_data.suite;
      Test_file_view.suite;
      Test_doc_comments.suite;
      Test_ast.suite;
      Test_outline.suite;
      Test_suite.suite;
      Test_protocol_modules.suite;
      Test_function_metrics.suite;
      Test_loc.suite;
      Test_type_kind.suite;
      Test_example.suite;
      Test_file.suite;
      Test_path.suite;
      Test_fs.suite;
      Test_guide.suite;
      Test_profiling.suite;
      Test_rule.suite;
      Test_config_doc.suite;
      Test_probe_events.suite;
      Test_e610.suite;
    ]
  in
  Alcotest.run "merlint" suites
