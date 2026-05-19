open Merlint

let test_run_empty_filter () =
  (* Test running with all rules disabled using "none" keyword *)
  match Filter.parse "none" with
  | Error msg -> Alcotest.failf "Failed to create filter: %s" msg
  | Ok filter ->
      Eio_main.run @@ fun env ->
      let dune_describe = Dune_describe.describe (Fpath.v ".") in
      let fs = Eio.Stdenv.fs env in
      let index ?pool () =
        ignore pool;
        Project_index.build ~fs ~monorepo:(Fpath.v ".") ()
      in
      let result =
        Engine.run
          ~load_file:(fun f -> In_channel.with_open_text f In_channel.input_all)
          ~filter ~dune_describe ~index "."
      in
      Alcotest.(check int)
        "no results with all rules disabled" 0
        (List.length result.Engine.issues)

let suite =
  ( "engine",
    [ Alcotest.test_case "run with empty filter" `Quick test_run_empty_filter ]
  )
