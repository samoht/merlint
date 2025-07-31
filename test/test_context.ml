(** Tests for Context module *)

let test_create_project () =
  (* Test creating a project context *)
  let config = Merlint.Config.default in
  let project_root = "." in
  let all_files = [ "foo.ml"; "bar.ml" ] in
  let dune_describe = Merlint.Dune.describe (Fpath.v ".") in
  let ctx =
    Merlint.Context.project ~config ~project_root ~all_files ~dune_describe
  in
  (* Test that we can access fields *)
  Alcotest.(check string) "project root" "." ctx.project_root;
  Alcotest.(check int)
    "file count" 2
    (List.length (Merlint.Context.all_files ctx))

let test_analysis_error () =
  (* Test that Analysis_error exception exists *)
  let result =
    try raise (Merlint.Context.Analysis_error "test error") with
    | Merlint.Context.Analysis_error msg -> msg
    | _ -> "wrong exception"
  in
  Alcotest.(check string) "error message" "test error" result

let test_lazy_evaluation () =
  (* Test that lazy fields work correctly *)
  let config = Merlint.Config.default in
  let project_root = "." in
  let files_evaluated = ref false in
  let all_files =
    lazy
      (files_evaluated := true;
       [ "test.ml" ])
  in
  let dune_describe = Merlint.Dune.describe (Fpath.v ".") in
  let ctx =
    {
      Merlint.Context.config;
      project_root;
      all_files;
      dune_describe = lazy dune_describe;
      executable_modules = lazy [];
      lib_modules = lazy [];
      test_modules = lazy [];
    }
  in
  (* Files should not be evaluated yet *)
  Alcotest.(check bool) "not evaluated" false !files_evaluated;
  (* Access the files *)
  let _ = Merlint.Context.all_files ctx in
  (* Now they should be evaluated *)
  Alcotest.(check bool) "evaluated" true !files_evaluated

let tests =
  [
    ("create_project", `Quick, test_create_project);
    ("analysis_error", `Quick, test_analysis_error);
    ("lazy_evaluation", `Quick, test_lazy_evaluation);
  ]

let suite = ("context", tests)
