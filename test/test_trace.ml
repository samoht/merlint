let test_span_returns () =
  Eio_main.run @@ fun _env ->
  Alcotest.(check int) "value" 42 (Merlint.Trace.span "test.span" (fun () -> 42))

let test_span_raises () =
  Eio_main.run @@ fun _env ->
  Alcotest.check_raises "raises" Exit (fun () ->
      Merlint.Trace.span "test.raises" (fun () -> raise Exit))

let test_named_spans () =
  Eio_main.run @@ fun _env ->
  Alcotest.(check string)
    "rule" "ok"
    (Merlint.Trace.rule_span "E000" (fun () -> "ok"));
  Alcotest.(check string)
    "merlin" "ok"
    (Merlint.Trace.merlin_span "typedtree" (fun () -> "ok"))

let suite =
  ( "trace",
    [
      Alcotest.test_case "span returns" `Quick test_span_returns;
      Alcotest.test_case "span raises" `Quick test_span_raises;
      Alcotest.test_case "named spans" `Quick test_named_spans;
    ] )
