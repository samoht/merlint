let () =
  let suites = Test_style_rules.suite in
  Alcotest.run "merlint" suites
