let () =
  let (name, tests) = Fuzz_parser.suite in
  let suite = (name, tests) in
  Crowbar.run_tests [ suite ]
