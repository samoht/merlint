open Merlint

let clear_cache () =
  (* Test that clear_cache doesn't throw an exception *)
  Dune.clear_cache ();
  Alcotest.(check bool) "cache cleared without error" true true

let suite =
  [ ("dune", [ Alcotest.test_case "clear cache" `Quick clear_cache ]) ]
