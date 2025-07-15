open Merlint

let analyze_file_nonexistent () =
  let result = Merlin.analyze_file "/nonexistent/file.ml" in

  (* All analyses should fail for nonexistent file *)
  Alcotest.(check bool)
    "outline should fail" true
    (Result.is_error result.outline);
  Alcotest.(check bool)
    "typedtree should fail" true
    (Result.is_error result.typedtree);
  Alcotest.(check bool)
    "browse should fail" true
    (Result.is_error result.browse)

let suite =
  [
    ( "merlin",
      [
        Alcotest.test_case "analyze nonexistent file" `Quick
          analyze_file_nonexistent;
      ] );
  ]
