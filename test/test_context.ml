(** Tests for Context module *)

let dummy_index = lazy (failwith "Project_index not built in tests")

let test_create_project () =
  let config = Merlint.Config.default in
  let project_root = "." in
  let analyze_set = [ "foo.ml"; "bar.ml" ] in
  let dune_describe = Merlint.Dune_describe.describe (Fpath.v ".") in
  let ctx =
    Merlint.Context.project ~config ~project_root ~analyze_set ~dune_describe
      ~index:dummy_index ()
  in
  Alcotest.(check string) "project root" "." ctx.project_root;
  Alcotest.(check (list string))
    "files to analyze" analyze_set
    (Merlint.Context.analyze_set ctx)

let test_analysis_error () =
  let result =
    try raise (Merlint.Context.Analysis_error "test error") with
    | Merlint.Context.Analysis_error msg -> msg
    | exn -> Printexc.to_string exn
  in
  Alcotest.(check string) "error message" "test error" result

let test_cache_canonicalizes_keys () =
  let config = Merlint.Config.default in
  let project_root = "." in
  let analyze_set = [ "foo.ml" ] in
  let dune_describe = Merlint.Dune_describe.describe (Fpath.v ".") in
  let created = ref 0 in
  let file_view filename =
    incr created;
    Merlint.File_view.v ~filename ~typedtree:(fun () -> Ok None) ()
  in
  let ctx =
    Merlint.Context.project ~config ~project_root ~analyze_set ~dune_describe
      ~index:dummy_index ~file_view ()
  in
  let a = Merlint.Context.file_view ctx "./foo.ml" in
  let b = Merlint.Context.file_view ctx "foo.ml" in
  Alcotest.(check bool) "same cached view" true (a == b);
  Alcotest.(check int) "created once" 1 !created

let tests =
  [
    ("create_project", `Quick, test_create_project);
    ("analysis_error", `Quick, test_analysis_error);
    ("file_view_cache_canonicalizes_keys", `Quick, test_cache_canonicalizes_keys);
  ]

let suite = ("context", tests)
