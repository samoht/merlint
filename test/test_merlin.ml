open Merlint

(* Test the data structure creation without I/O *)
let test_result_structure () =
  let mock_browse = Ok (Browse.empty ()) in
  let mock_typedtree = Error "Mock error" in
  let mock_outline = Ok (Outline.empty ()) in

  let result =
    Merlin.
      {
        browse = mock_browse;
        typedtree = mock_typedtree;
        outline = mock_outline;
      }
  in

  (* Test the result structure *)
  Alcotest.(check bool)
    "browse should succeed" true
    (Result.is_ok result.browse);
  Alcotest.(check bool)
    "typedtree should fail" true
    (Result.is_error result.typedtree);
  Alcotest.(check bool)
    "outline should succeed" true
    (Result.is_ok result.outline)

let suite =
  [
    ( "merlin",
      [ Alcotest.test_case "result structure" `Quick test_result_structure ] );
  ]
