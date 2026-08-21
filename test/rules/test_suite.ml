let unresolved_view ?(filename = "test_suite.mli") () =
  Merlint.File_view.v ~filename
    ~content:(lazy "")
    ~typedtree:(fun () -> Ok None)
    ()

let with_eio f = Eio_main.run @@ fun _env -> f ()

let test_unknown_type_lazy () =
  with_eio @@ fun () ->
  let forced = ref false in
  let view =
    Merlint.File_view.v ~filename:"test_suite.mli"
      ~content:(lazy "")
      ~typedtree:(fun () ->
        forced := true;
        Ok None)
      ()
  in
  Alcotest.(check bool)
    "rejected" true
    (Merlint.Suite.is_compliant_view ~expected:"unknown" view
    = Merlint.Suite.Resolved false);
  Alcotest.(check bool) "typedtree not forced" false !forced

let test_unresolved_skips () =
  with_eio @@ fun () ->
  let view = unresolved_view () in
  (* Not "not compliant": without a typedtree the type cannot be read, and a
     caller that takes the absent answer for a mismatch reports every compliant
     interface in an unbuilt tree. *)
  Alcotest.(check bool)
    "compliance unresolved without typedtree" true
    (Merlint.Suite.is_compliant_view
       ~expected:"string * unit Alcotest.test_case list" view
    = Merlint.Suite.Unresolved);
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
