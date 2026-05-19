let empty_view filename =
  Merlint.File_view.v ~filename ~typedtree:(fun () -> Ok None) ()

let test_empty_build () =
  let calls = ref 0 in
  let analysis =
    Merlint.Analysis.build ~domain_mgr:None
      ~view_of:(fun filename ->
        incr calls;
        empty_view filename)
      []
  in
  Alcotest.(check int) "no views" 0 !calls;
  Alcotest.(check bool)
    "missing caller" true
    (Option.is_none (Merlint.Analysis.suite_callers analysis "test.ml"))

let test_builds_once () =
  Eio_main.run @@ fun _env ->
  let calls = ref [] in
  let analysis =
    Merlint.Analysis.build ~domain_mgr:None
      ~view_of:(fun filename ->
        calls := filename :: !calls;
        empty_view filename)
      [ "a.ml"; "b.ml" ]
  in
  Alcotest.(check (list string)) "visited" [ "b.ml"; "a.ml" ] !calls;
  Alcotest.(check bool)
    "stored none" true
    (Option.is_none (Merlint.Analysis.suite_callers analysis "a.ml"))

let suite =
  ( "analysis",
    [
      Alcotest.test_case "empty build" `Quick test_empty_build;
      Alcotest.test_case "builds once" `Quick test_builds_once;
    ] )
