open Merlint

let test_run_empty_filter () =
  (* Test running with all rules disabled using "none" keyword *)
  match Filter.parse "none" with
  | Error msg -> Alcotest.failf "Failed to create filter: %s" msg
  | Ok filter ->
      let dune_describe = Dune.describe (Fpath.v ".") in
      let results = Engine.run ~filter ~dune_describe "." in
      Alcotest.(check int)
        "no results with all rules disabled" 0 (List.length results)

let suite =
  ( "engine",
    [ Alcotest.test_case "run with empty filter" `Quick test_run_empty_filter ]
  )
