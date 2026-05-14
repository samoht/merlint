(* Machine-checkable test for the [merlint help config] examples.

   Each example in [Merlint_doc.Config_doc.examples] is the source-of-truth
   TOML fragment shown in the man page. The test parses every fragment
   through [Merlint.Config_parser.parse]; if any of them stops parsing
   (because the parser changed shape and the docs lagged behind), the
   test fails loudly. That keeps [merlint help config] honest. *)

let test_example (label, content) =
  match Merlint.Config_parser.parse content with
  | _ -> ()
  | exception Failure msg ->
      Alcotest.failf "config example %S failed to parse: %s" label msg

let test_all_examples_parse () =
  List.iter test_example Merlint_doc.Config_doc.examples

let test_examples_non_empty () =
  Alcotest.(check bool)
    "config_doc ships at least one example" true
    (Merlint_doc.Config_doc.examples <> [])

let suite =
  ( "config_doc",
    [
      Alcotest.test_case "examples non-empty" `Quick test_examples_non_empty;
      Alcotest.test_case "every example parses" `Quick test_all_examples_parse;
    ] )
