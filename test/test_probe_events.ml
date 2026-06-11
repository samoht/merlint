let test_analysis_returns_value () =
  let value =
    Merlint.Probe_events.analysis ~project_root:"/tmp/project" ~files:2 ~rules:3
      (fun () -> 42)
  in
  Alcotest.(check int) "value" 42 value

let test_project_rule_raises () =
  let exn = Failure "probe body failed" in
  Alcotest.check_raises "same exception" exn (fun () ->
      Merlint.Probe_events.project_rule ~rule:"E923" (fun () -> raise exn))

let suite =
  ( "probe_events",
    [
      Alcotest.test_case "analysis returns value" `Quick
        test_analysis_returns_value;
      Alcotest.test_case "project_rule raises" `Quick test_project_rule_raises;
    ] )
