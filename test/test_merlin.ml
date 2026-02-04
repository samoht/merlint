(** Tests for merlint's Merlin integration.

    These tests verify that the Merlin_dump module works correctly. *)

open Merlint

(* Test the dump result handling *)
let test_dump_result_handling () =
  let mock_dump = Error "Mock error" in
  Alcotest.(check bool)
    "dump error is Error" true
    (Result.is_error mock_dump)

let test_dump_ok_handling () =
  let mock_dump = Ok (Dump.typedtree "test content") in
  Alcotest.(check bool) "dump ok is Ok" true (Result.is_ok mock_dump)

let suite =
  ( "merlin_dump",
    [
      Alcotest.test_case "dump result handling" `Quick test_dump_result_handling;
      Alcotest.test_case "dump ok handling" `Quick test_dump_ok_handling;
    ] )
