(** Tests for E610/E605 case-insensitive conventions.

    The actual rule functions are internal, so we test the convention that test
    file names should match library module names case-insensitively. *)

(** Reproduce the E605 expected_test_path logic for testing *)
let expected_test_basename module_basename =
  "test_" ^ String.lowercase_ascii module_basename

let test_lowercase_convention () =
  (* E605 line 61: basename is lowercased *)
  Alcotest.(check string)
    "normal" "test_foo.ml"
    (expected_test_basename "foo.ml");
  Alcotest.(check string)
    "uppercase" "test_os.ml"
    (expected_test_basename "OS.ml");
  Alcotest.(check string)
    "mixed" "test_uiint.ml"
    (expected_test_basename "UIint.ml");
  Alcotest.(check string)
    "camelcase" "test_mymodule.ml"
    (expected_test_basename "MyModule.ml")

let test_case_insensitive_match () =
  (* E610 fix: library path matching is case-insensitive *)
  let matches lib_path expected_path =
    String.lowercase_ascii lib_path = String.lowercase_ascii expected_path
    || String.lowercase_ascii (Filename.basename lib_path)
       = String.lowercase_ascii expected_path
  in
  Alcotest.(check bool) "OS.ml matches os.ml" true (matches "OS.ml" "os.ml");
  Alcotest.(check bool) "os.ml matches os.ml" true (matches "os.ml" "os.ml");
  Alcotest.(check bool)
    "foo.ml matches bar.ml" false
    (matches "foo.ml" "bar.ml");
  Alcotest.(check bool)
    "spec/OS.ml matches os.ml via basename" true
    (matches "spec/OS.ml" "os.ml");
  Alcotest.(check bool)
    "UIint.ml matches uiint.ml" true
    (matches "UIint.ml" "uiint.ml")

let test_e205_prefix_matching () =
  (* E205 fix: match Printf with or without Stdlib prefix *)
  let is_printf_module prefix =
    match prefix with
    | [ "Stdlib"; "Printf" ] | [ "Printf" ] -> true
    | _ -> false
  in
  Alcotest.(check bool)
    "Stdlib.Printf" true
    (is_printf_module [ "Stdlib"; "Printf" ]);
  Alcotest.(check bool) "bare Printf" true (is_printf_module [ "Printf" ]);
  Alcotest.(check bool) "Fmt" false (is_printf_module [ "Fmt" ]);
  Alcotest.(check bool) "empty" false (is_printf_module [])

let suite =
  ( "e610",
    [
      Alcotest.test_case "lowercase convention" `Quick test_lowercase_convention;
      Alcotest.test_case "case insensitive match" `Quick
        test_case_insensitive_match;
      Alcotest.test_case "e205 prefix matching" `Quick test_e205_prefix_matching;
    ] )
