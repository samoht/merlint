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
let with_eio f = Eio_main.run @@ fun _env -> f ()

let test_lazy_without_access () =
  let typedtree_calls = ref 0 in
  let _ =
    view "lazy.ml" (fun () ->
        incr typedtree_calls;
        Ok (Some (empty_implementation, Merlin.Recorded)))
  in
  Alcotest.(check int) "typedtree not loaded" 0 !typedtree_calls

let test_typedtree_loaded_once () =
  with_eio @@ fun () ->
  let typedtree_calls = ref 0 in
  let v =
    view "once.ml" (fun () ->
        incr typedtree_calls;
        Ok (Some (empty_implementation, Merlin.Recorded)))
  in
  Alcotest.(check bool) "resolved" true (Merlint.File_view.is_resolved v);
  Alcotest.(check bool)
    "same availability" true
    (Option.is_some (Merlint.File_view.typedtree v));
  Alcotest.(check int) "loaded once" 1 !typedtree_calls

let test_missing_typedtree_is_empty () =
  with_eio @@ fun () ->
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
  with_eio @@ fun () ->
  let v =
    view "iface.mli" (fun () -> Ok (Some (empty_interface, Merlin.Recorded)))
  in
  Alcotest.(check int)
    "no implementation values" 0
    (List.length (Merlint.File_view.values v))

let test_application_cache_without_implementation () =
  with_eio @@ fun () ->
  let v =
    view "iface.mli" (fun () -> Ok (Some (empty_interface, Merlin.Recorded)))
  in
  let calls = ref 0 in
  Merlint.File_view.iter_applications v (fun _ -> incr calls);
  Alcotest.(check int) "no calls" 0 !calls

let test_typedtree_loaded_across_domains () =
  Eio_main.run @@ fun env ->
  let typedtree_calls = Atomic.make 0 in
  let v =
    view "parallel.ml" (fun () ->
        ignore (Atomic.fetch_and_add typedtree_calls 1);
        Unix.sleepf 0.05;
        Ok (Some (empty_implementation, Merlin.Recorded)))
  in
  let dm = Eio.Stdenv.domain_mgr env in
  let results =
    Merlint.Fs.with_pool dm @@ fun pool ->
    Merlint.Fs.parallel_map pool [ 1; 2; 3; 4 ] (fun _ ->
        Merlint.File_view.is_resolved v)
  in
  Alcotest.(check (list bool)) "all resolved" [ true; true; true; true ] results;
  Alcotest.(check int) "typedtree loaded once" 1 (Atomic.get typedtree_calls)

(* A tree typechecked from source carries no doc comments, and a view over one
   must say so: a rule that reads doc comments would otherwise read the absence
   of every one of them as a source with no documentation and report on all of
   it. An absent tree has none to speak of either. *)
let test_docs_recorded_follows_the_tree () =
  with_eio @@ fun () ->
  let recorded =
    view "recorded.mli" (fun () -> Ok (Some (empty_interface, Merlin.Recorded)))
  in
  Alcotest.(check bool)
    "artefact tree records docs" true
    (Merlint.File_view.docs_recorded recorded);
  let typechecked =
    view "typechecked.mli" (fun () ->
        Ok (Some (empty_interface, Merlin.Unavailable)))
  in
  Alcotest.(check bool)
    "typechecked tree does not" false
    (Merlint.File_view.docs_recorded typechecked);
  let absent = view "absent.mli" (fun () -> Ok None) in
  Alcotest.(check bool)
    "absent tree does not" false
    (Merlint.File_view.docs_recorded absent)

let tests =
  [
    ("no_typedtree_load_without_access", `Quick, test_lazy_without_access);
    ("typedtree_loaded_once", `Quick, test_typedtree_loaded_once);
    ("missing_typedtree_is_empty", `Quick, test_missing_typedtree_is_empty);
    ("interface_has_no_values", `Quick, test_interface_has_no_values);
    ( "application_cache_empty_without_implementation",
      `Quick,
      test_application_cache_without_implementation );
    ( "typedtree_loaded_once_across_domains",
      `Quick,
      test_typedtree_loaded_across_domains );
    ( "docs_recorded_follows_the_tree",
      `Quick,
      test_docs_recorded_follows_the_tree );
  ]

let suite = ("file_view", tests)
