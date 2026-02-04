open Merlint

(* Test the data structure creation without I/O *)
let test_result_structure () =
  let mock_dump = Error "Mock error" in
  let mock_outline = Ok (Outline.empty ()) in

  let result = Merlin.{ dump = mock_dump; outline = mock_outline } in

  (* Test the result structure *)
  Alcotest.(check bool) "dump should fail" true (Result.is_error result.dump);
  Alcotest.(check bool)
    "outline should succeed" true
    (Result.is_ok result.outline)

let suite =
  ( "merlin",
    [ Alcotest.test_case "result structure" `Quick test_result_structure ] )
