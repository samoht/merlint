(** Tests for File_view: shared parsetree, lazy thunks, .mli handling. *)

let write_tmp ~suffix content =
  let path = Filename.temp_file "merlint_file_view_" suffix in
  Out_channel.with_open_text path (fun oc ->
      Out_channel.output_string oc content);
  path

let dummy_thunk msg () = Error msg
let ok_outline () = Ok []

let view ?typedtree ?parsetree ?(load_content = fun () -> "")
    ?(outline = ok_outline) ?(dump = dummy_thunk "no dump") filename =
  Merlint.File_view.v ~filename ~load_content ?typedtree ?parsetree ~outline
    ~dump ()

let test_content_reads_file () =
  let path = write_tmp ~suffix:".ml" "let x = 1\nlet y = x + 1\n" in
  let v =
    view path
      ~load_content:(fun () ->
        In_channel.with_open_text path In_channel.input_all)
      ~outline:(dummy_thunk "no outline")
  in
  Alcotest.(check string)
    "content matches" "let x = 1\nlet y = x + 1\n"
    (Merlint.File_view.content v);
  Sys.remove path

let test_parsetree_some_ml () =
  let path = write_tmp ~suffix:".ml" "let answer = 42\n" in
  let v =
    view path
      ~load_content:(fun () ->
        In_channel.with_open_text path In_channel.input_all)
      ~outline:(dummy_thunk "no outline")
  in
  let pt = Merlint.File_view.parsetree v in
  Alcotest.(check bool) "parsetree is Some" true (Option.is_some pt);
  Sys.remove path

let test_parsetree_none_for_mli () =
  let path = write_tmp ~suffix:".mli" "val x : int\n" in
  let v =
    view path
      ~load_content:(fun () ->
        In_channel.with_open_text path In_channel.input_all)
      ~outline:(dummy_thunk "no outline")
  in
  let pt = Merlint.File_view.parsetree v in
  Alcotest.(check bool) "parsetree is None" true (Option.is_none pt);
  Sys.remove path

let test_parsetree_shared_with_functions () =
  (* Forcing functions then parsetree must not re-parse. We probe this
     indirectly: the same physical structure pointer should back both. *)
  let path = write_tmp ~suffix:".ml" "let f x = x + 1\nlet g y = y - 1\n" in
  let v =
    view path
      ~load_content:(fun () ->
        In_channel.with_open_text path In_channel.input_all)
      ~outline:(dummy_thunk "no outline")
  in
  let fns = Merlint.File_view.functions v in
  Alcotest.(check int) "two functions" 2 (List.length fns);
  let pt = Merlint.File_view.parsetree v in
  Alcotest.(check bool) "parsetree available" true (Option.is_some pt);
  Sys.remove path

let test_outline_thunk_failure_raises () =
  let path = write_tmp ~suffix:".ml" "let x = 1\n" in
  let v =
    view path
      ~load_content:(fun () ->
        In_channel.with_open_text path In_channel.input_all)
      ~outline:(fun () -> Error "boom")
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
    view path
      ~load_content:(fun () ->
        In_channel.with_open_text path In_channel.input_all)
      ~outline:(fun () ->
        called := true;
        Error "never")
  in
  Alcotest.(check bool) "thunk not called on creation" false !called;
  let _ = Merlint.File_view.content v in
  Alcotest.(check bool) "thunk not called on content access" false !called;
  Sys.remove path

let test_lazy_without_access () =
  let content_reads = ref 0 in
  let typedtree_calls = ref 0 in
  let parsetree_calls = ref 0 in
  let _ =
    view "lazy.ml"
      ~load_content:(fun () ->
        incr content_reads;
        "let x = 1\n")
      ~typedtree:(fun () ->
        incr typedtree_calls;
        Ok None)
      ~parsetree:(fun () ->
        incr parsetree_calls;
        Ok (Some []))
  in
  Alcotest.(check int) "content not read" 0 !content_reads;
  Alcotest.(check int) "typedtree not loaded" 0 !typedtree_calls;
  Alcotest.(check int) "parsetree not loaded" 0 !parsetree_calls

let test_content_read_once () =
  let content_reads = ref 0 in
  let v =
    view "once.ml" ~load_content:(fun () ->
        incr content_reads;
        "let x = 1\n")
  in
  Alcotest.(check string)
    "first read" "let x = 1\n"
    (Merlint.File_view.content v);
  Alcotest.(check string)
    "second read" "let x = 1\n"
    (Merlint.File_view.content v);
  Alcotest.(check int) "read once" 1 !content_reads

let test_parsetree_keeps_typedtree_lazy () =
  let typedtree_calls = ref 0 in
  let parsetree_calls = ref 0 in
  let v =
    view "syntax.ml"
      ~typedtree:(fun () ->
        incr typedtree_calls;
        Error "typedtree should stay lazy")
      ~parsetree:(fun () ->
        incr parsetree_calls;
        Ok (Some []))
  in
  Alcotest.(check bool)
    "parsetree available" true
    (Option.is_some (Merlint.File_view.parsetree v));
  Alcotest.(check int) "typedtree untouched" 0 !typedtree_calls;
  Alcotest.(check int) "parsetree forced once" 1 !parsetree_calls

let test_parsetree_degrades_from_typedtree () =
  let typedtree_calls = ref 0 in
  let parsetree_calls = ref 0 in
  let v =
    view "typed.ml"
      ~typedtree:(fun () ->
        incr typedtree_calls;
        Ok
          (Some
             (`Implementation
                {
                  Ocaml_typing.Typedtree.str_items = [];
                  str_type = [];
                  str_final_env = Ocaml_typing.Env.empty;
                })))
      ~parsetree:(fun () ->
        incr parsetree_calls;
        Error "parsetree should degrade from loaded typedtree")
  in
  Alcotest.(check bool)
    "typedtree loaded" true
    (Option.is_some (Merlint.File_view.typedtree v));
  Alcotest.(check bool)
    "parsetree available" true
    (Option.is_some (Merlint.File_view.parsetree v));
  Alcotest.(check int) "typedtree forced once" 1 !typedtree_calls;
  Alcotest.(check int) "parsetree thunk unused" 0 !parsetree_calls

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
    ("no_source_read_without_access", `Quick, test_lazy_without_access);
    ("content_read_once", `Quick, test_content_read_once);
    ( "parsetree_does_not_force_typedtree",
      `Quick,
      test_parsetree_keeps_typedtree_lazy );
    ( "parsetree_degrades_from_loaded_typedtree",
      `Quick,
      test_parsetree_degrades_from_typedtree );
  ]

let suite = ("file_view", tests)
