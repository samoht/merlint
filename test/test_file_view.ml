(** Tests for File_view's typedtree-backed lazy cache. *)

let empty_implementation =
  `Implementation
    {
      Ocaml_typing.Typedtree.str_items = [];
      str_type = [];
      str_final_env = Ocaml_typing.Env.empty;
    }

let empty_interface =
  `Interface
    {
      Ocaml_typing.Typedtree.sig_items = [];
      sig_type = [];
      sig_final_env = Ocaml_typing.Env.empty;
    }

let view filename typedtree = Merlint.File_view.v ~filename ~typedtree ()

let test_lazy_without_access () =
  let typedtree_calls = ref 0 in
  let _ =
    view "lazy.ml" (fun () ->
        incr typedtree_calls;
        Ok (Some empty_implementation))
  in
  Alcotest.(check int) "typedtree not loaded" 0 !typedtree_calls

let test_typedtree_loaded_once () =
  let typedtree_calls = ref 0 in
  let v =
    view "once.ml" (fun () ->
        incr typedtree_calls;
        Ok (Some empty_implementation))
  in
  Alcotest.(check bool) "resolved" true (Merlint.File_view.is_resolved v);
  Alcotest.(check bool)
    "same availability" true
    (Option.is_some (Merlint.File_view.typedtree v));
  Alcotest.(check int) "loaded once" 1 !typedtree_calls

let test_missing_typedtree_is_empty () =
  let typedtree_calls = ref 0 in
  let v =
    view "missing.ml" (fun () ->
        incr typedtree_calls;
        Ok None)
  in
  Alcotest.(check bool) "not resolved" false (Merlint.File_view.is_resolved v);
  Alcotest.(check int) "no items" 0 (List.length (Merlint.File_view.items v));
  Alcotest.(check int) "loaded once" 1 !typedtree_calls

let test_interface_has_no_values () =
  let v = view "iface.mli" (fun () -> Ok (Some empty_interface)) in
  Alcotest.(check int)
    "no implementation values" 0
    (List.length (Merlint.File_view.values v))

let test_application_cache_is_empty_without_implementation () =
  let v = view "iface.mli" (fun () -> Ok (Some empty_interface)) in
  let calls = ref 0 in
  Merlint.File_view.iter_applications v (fun _ -> incr calls);
  Alcotest.(check int) "no calls" 0 !calls

let tests =
  [
    ("no_typedtree_load_without_access", `Quick, test_lazy_without_access);
    ("typedtree_loaded_once", `Quick, test_typedtree_loaded_once);
    ("missing_typedtree_is_empty", `Quick, test_missing_typedtree_is_empty);
    ("interface_has_no_values", `Quick, test_interface_has_no_values);
    ( "application_cache_empty_without_implementation",
      `Quick,
      test_application_cache_is_empty_without_implementation );
  ]

let suite = ("file_view", tests)
