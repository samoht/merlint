(* Adversarial tests for [Merlint.Opam_tags]. The lint claims this module
   reads opam tag fields safely; the tests probe the corners the author
   hoped you wouldn't try. *)

open Merlint

let with_tmp_file content f =
  let path = Filename.temp_file "merlint-opam-tags" ".opam" in
  let oc = open_out path in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc content);
  Fun.protect ~finally:(fun () -> Sys.remove path) (fun () -> f path)

let test_list_form () =
  with_tmp_file {|opam-version: "2.0"
tags: ["codec.json" "org:blacksun"]
|}
    (fun path ->
      Alcotest.(check (option (list string)))
        "list of two tags"
        (Some [ "codec.json"; "org:blacksun" ])
        (Opam_tags.read_opt path))

let test_single_string_form () =
  with_tmp_file {|opam-version: "2.0"
tags: "protocol"
|} (fun path ->
      Alcotest.(check (option (list string)))
        "single string normalised to singleton list" (Some [ "protocol" ])
        (Opam_tags.read_opt path))

let test_field_absent () =
  with_tmp_file {|opam-version: "2.0"
name: "no-tags-here"
|} (fun path ->
      Alcotest.(check (option (list string)))
        "absent field -> None" None (Opam_tags.read_opt path);
      Alcotest.(check (list string))
        "read folds None into []" [] (Opam_tags.read path))

let test_file_missing () =
  let path = "/this/path/does/not/exist.opam" in
  Alcotest.(check (option (list string)))
    "missing file -> None" None (Opam_tags.read_opt path);
  Alcotest.(check (list string))
    "read tolerates missing file" [] (Opam_tags.read path)

let test_empty_list_kept () =
  with_tmp_file {|opam-version: "2.0"
tags: []
|} (fun path ->
      Alcotest.(check (option (list string)))
        "empty list is distinguished from absent" (Some [])
        (Opam_tags.read_opt path))

let test_non_string_entries_dropped () =
  (* Spec: [tags:] holds strings. Non-string items in a list (rare but legal
     opam syntax) must be silently dropped rather than crashing the rule. *)
  with_tmp_file {|opam-version: "2.0"
tags: ["codec" 42 "protocol"]
|}
    (fun path ->
      Alcotest.(check (option (list string)))
        "ints inside the list are dropped"
        (Some [ "codec"; "protocol" ])
        (Opam_tags.read_opt path))

let test_other_value () =
  (* If the field exists but its value is neither a string nor a list (e.g.
     [tags: true]), behaviour is to return [Some []] -- field is "present
     but empty as far as we can tell". *)
  with_tmp_file {|opam-version: "2.0"
tags: true
|} (fun path ->
      Alcotest.(check (option (list string)))
        "non-string/non-list value -> Some []" (Some [])
        (Opam_tags.read_opt path))

let test_is_sans_io_predicate () =
  Alcotest.(check bool)
    "bare [codec] matches" true
    (Opam_tags.is_sans_io "codec");
  Alcotest.(check bool)
    "[codec.json] matches" true
    (Opam_tags.is_sans_io "codec.json");
  Alcotest.(check bool)
    "[protocol] matches" true
    (Opam_tags.is_sans_io "protocol");
  Alcotest.(check bool)
    "[eio] does not match" false
    (Opam_tags.is_sans_io "eio");
  Alcotest.(check bool)
    "[org:blacksun] does not match" false
    (Opam_tags.is_sans_io "org:blacksun");
  (* Adversarial: short strings starting with [codec] but missing the dot. *)
  Alcotest.(check bool)
    "[codec_] does NOT match (no dot)" false
    (Opam_tags.is_sans_io "codec_");
  Alcotest.(check bool)
    "[codecs] does NOT match" false
    (Opam_tags.is_sans_io "codecs");
  Alcotest.(check bool)
    "[codec.] (dot but no subtag) does NOT match" false
    (Opam_tags.is_sans_io "codec.");
  Alcotest.(check bool) "empty string" false (Opam_tags.is_sans_io "")

let test_has_sans_io () =
  Alcotest.(check bool)
    "any sans-io tag in the list" true
    (Opam_tags.has_sans_io [ "org:blacksun"; "codec.cbor" ]);
  Alcotest.(check bool)
    "no sans-io tag" false
    (Opam_tags.has_sans_io [ "org:blacksun"; "eio" ]);
  Alcotest.(check bool) "empty list" false (Opam_tags.has_sans_io [])

let suite =
  ( "opam_tags",
    [
      Alcotest.test_case "list form" `Quick test_list_form;
      Alcotest.test_case "single string form" `Quick test_single_string_form;
      Alcotest.test_case "field absent" `Quick test_field_absent;
      Alcotest.test_case "file missing" `Quick test_file_missing;
      Alcotest.test_case "empty list kept" `Quick test_empty_list_kept;
      Alcotest.test_case "non-string entries dropped" `Quick
        test_non_string_entries_dropped;
      Alcotest.test_case "non-string non-list value" `Quick test_other_value;
      Alcotest.test_case "is_sans_io predicate" `Quick test_is_sans_io_predicate;
      Alcotest.test_case "has_sans_io" `Quick test_has_sans_io;
    ] )
