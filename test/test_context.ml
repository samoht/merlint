(** Tests for Context module *)

let dummy_index = lazy (failwith "Project_index not built in tests")

let test_create_project () =
  let config = Merlint.Config.default in
  let project_root = Merlint.Context.path (Sys.getcwd ()) in
  let analyze_set =
    [
      Merlint.Context.path_under ~root:project_root "foo.ml";
      Merlint.Context.path_under ~root:project_root "bar.ml";
    ]
  in
  let ctx =
    Merlint.Context.project ~config ~project_root ~analyze_set
      ~index:dummy_index ()
  in
  Alcotest.(check string)
    "project root" (Sys.getcwd ())
    (Merlint.Context.project_root_path ctx);
  Alcotest.(check (list string))
    "files to analyze"
    (List.map Merlint.Context.string_of_path analyze_set)
    (Merlint.Context.analyze_set ctx |> List.map Merlint.Context.string_of_path)

(* path_under accepts a relative path under a relative "." root (the project
   root the engine uses when invoked as "."), canonicalises it to an absolute
   path, and still rejects a path that escapes the root. *)
let test_path_under_relative_root () =
  let root = Merlint.Context.path "." in
  let p = Merlint.Context.path_under ~root "bottler/bin/cmd_build.ml" in
  Alcotest.(check string)
    "under-root path is canonical absolute"
    (Merlint.Context.string_of_path
       (Merlint.Context.path "bottler/bin/cmd_build.ml"))
    (Merlint.Context.string_of_path p);
  Alcotest.check_raises "escaping path rejected"
    (Invalid_argument
       (Fmt.str "Path: %S escapes %S" "../escape.ml"
          (Merlint.Context.string_of_path root)))
    (fun () -> ignore (Merlint.Context.path_under ~root "../escape.ml"))

let test_analysis_error () =
  let result =
    try raise (Merlint.Context.Analysis_error "test error") with
    | Merlint.Context.Analysis_error msg -> msg
    | exn -> Printexc.to_string exn
  in
  Alcotest.(check string) "error message" "test error" result

let test_cache_canonicalizes_keys () =
  Eio_main.run @@ fun _env ->
  let config = Merlint.Config.default in
  let project_root = Merlint.Context.path (Sys.getcwd ()) in
  let analyze_set =
    [ Merlint.Context.path_under ~root:project_root "foo.ml" ]
  in
  let created = ref 0 in
  let file_view filename =
    incr created;
    Merlint.File_view.v
      ~filename:(Merlint.Context.string_of_path filename)
      ~typedtree:(fun () -> Ok None)
      ()
  in
  let ctx =
    Merlint.Context.project ~config ~project_root ~analyze_set
      ~index:dummy_index ~file_view ()
  in
  let a =
    Merlint.Context.file_view ctx
      (Merlint.Context.path_under ~root:project_root "./foo.ml")
  in
  let b =
    Merlint.Context.file_view ctx
      (Merlint.Context.path_under ~root:project_root "foo.ml")
  in
  Alcotest.(check bool) "same cached view" true (a == b);
  Alcotest.(check int) "created once" 1 !created

let tests =
  [
    ("create_project", `Quick, test_create_project);
    ("path_under_relative_root", `Quick, test_path_under_relative_root);
    ("analysis_error", `Quick, test_analysis_error);
    ("file_view_cache_canonicalizes_keys", `Quick, test_cache_canonicalizes_keys);
  ]

let suite = ("context", tests)
