let unresolved_view ?(filename = "test_suite.mli") () =
  Merlint.File_view.v ~filename ~typedtree:(fun () -> Ok None) ()

let with_eio f = Eio_main.run @@ fun _env -> f ()

let test_unknown_type_lazy () =
  with_eio @@ fun () ->
  let forced = ref false in
  let view =
    Merlint.File_view.v ~filename:"test_suite.mli"
      ~typedtree:(fun () ->
        forced := true;
        Ok None)
      ()
  in
  Alcotest.(check bool)
    "rejected" false
    (Merlint.Suite.is_compliant_view ~expected:"unknown" view);
  Alcotest.(check bool) "typedtree not forced" false !forced

let test_unresolved_skips () =
  with_eio @@ fun () ->
  let view = unresolved_view () in
  Alcotest.(check bool)
    "not compliant without typedtree" false
    (Merlint.Suite.is_compliant_view
       ~expected:"string * unit Alcotest.test_case list" view);
  Alcotest.(check bool)
    "references unresolved" true
    (Merlint.Suite.references view "Test_foo" = Merlint.Suite.Unresolved);
  Alcotest.(check bool)
    "prefixed references unresolved" true
    (Merlint.Suite.references_with_prefix view ~prefix:"Test_"
    = Merlint.Suite.Unresolved);
  Alcotest.(check bool)
    "test cases unresolved" true
    (Merlint.Suite.calls_test_case view = Merlint.Suite.Unresolved)

let suite =
  ( "suite",
    [
      ("unknown_type_lazy", `Quick, test_unknown_type_lazy);
      ("unresolved_skips", `Quick, test_unresolved_skips);
    ] )
