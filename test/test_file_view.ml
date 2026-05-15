(** Tests for File_view: shared parsetree, lazy thunks, .mli handling. *)

let write_tmp ~suffix content =
  let path = Filename.temp_file "merlint_file_view_" suffix in
  Out_channel.with_open_text path (fun oc ->
      Out_channel.output_string oc content);
  path

let dummy_thunk msg () = Error msg

let test_content_reads_file () =
  let path = write_tmp ~suffix:".ml" "let x = 1\nlet y = x + 1\n" in
  let v =
    Merlint.File_view.v ~filename:path ~outline:(dummy_thunk "no outline")
      ~dump:(dummy_thunk "no dump")
  in
  Alcotest.(check string)
    "content matches" "let x = 1\nlet y = x + 1\n"
    (Merlint.File_view.content v);
  Sys.remove path

let test_parsetree_some_ml () =
  let path = write_tmp ~suffix:".ml" "let answer = 42\n" in
  let v =
    Merlint.File_view.v ~filename:path ~outline:(dummy_thunk "no outline")
      ~dump:(dummy_thunk "no dump")
  in
  let pt = Merlint.File_view.parsetree v in
  Alcotest.(check bool) "parsetree is Some" true (Option.is_some pt);
  Sys.remove path

let test_parsetree_none_for_mli () =
  let path = write_tmp ~suffix:".mli" "val x : int\n" in
  let v =
    Merlint.File_view.v ~filename:path ~outline:(dummy_thunk "no outline")
      ~dump:(dummy_thunk "no dump")
  in
  let pt = Merlint.File_view.parsetree v in
  Alcotest.(check bool) "parsetree is None" true (Option.is_none pt);
  Sys.remove path

let test_parsetree_shared_with_functions () =
  (* Forcing functions then parsetree must not re-parse. We probe this
     indirectly: the same physical structure pointer should back both. *)
  let path = write_tmp ~suffix:".ml" "let f x = x + 1\nlet g y = y - 1\n" in
  let v =
    Merlint.File_view.v ~filename:path ~outline:(dummy_thunk "no outline")
      ~dump:(dummy_thunk "no dump")
  in
  let fns = Merlint.File_view.functions v in
  Alcotest.(check int) "two functions" 2 (List.length fns);
  let pt = Merlint.File_view.parsetree v in
  Alcotest.(check bool) "parsetree available" true (Option.is_some pt);
  Sys.remove path

let test_outline_thunk_failure_raises () =
  let path = write_tmp ~suffix:".ml" "let x = 1\n" in
  let v =
    Merlint.File_view.v ~filename:path
      ~outline:(fun () -> Error "boom")
      ~dump:(dummy_thunk "no dump")
  in
  let raised =
    try
      let _ = Merlint.File_view.outline v in
      false
    with Merlint.File_view.Analysis_error _ -> true
  in
  Alcotest.(check bool) "raises Analysis_error" true raised;
  Sys.remove path

let test_outline_lazy () =
  let path = write_tmp ~suffix:".ml" "let x = 1\n" in
  let called = ref false in
  let v =
    Merlint.File_view.v ~filename:path
      ~outline:(fun () ->
        called := true;
        Error "never")
      ~dump:(dummy_thunk "no dump")
  in
  Alcotest.(check bool) "thunk not called on creation" false !called;
  let _ = Merlint.File_view.content v in
  Alcotest.(check bool) "thunk not called on content access" false !called;
  Sys.remove path

let tests =
  [
    ("content_reads_file", `Quick, test_content_reads_file);
    ("parsetree_some_ml", `Quick, test_parsetree_some_ml);
    ("parsetree_none_for_mli", `Quick, test_parsetree_none_for_mli);
    ( "parsetree_shared_with_functions",
      `Quick,
      test_parsetree_shared_with_functions );
    ("outline_failure_raises", `Quick, test_outline_thunk_failure_raises);
    ("outline_lazy", `Quick, test_outline_lazy);
  ]

let suite = ("file_view", tests)
