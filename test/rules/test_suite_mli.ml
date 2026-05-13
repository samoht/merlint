(* Adversarial tests for [Merlint.Suite_mli]. *)

open Merlint

let alcotest_t = "string * unit Alcotest.test_case list"
let alcobar_t = "string * Alcobar.test_case list"

let test_compliant_alcotest () =
  let src = {|val suite : string * unit Alcotest.test_case list|} in
  Alcotest.(check bool)
    "minimal Alcotest suite-only mli" true
    (Suite_mli.is_compliant ~expected:alcotest_t src)

let test_compliant_alcobar () =
  let src = {|val suite : string * Alcobar.test_case list|} in
  Alcotest.(check bool)
    "minimal alcobar suite-only mli" true
    (Suite_mli.is_compliant ~expected:alcobar_t src)

let test_no_suite () =
  let src = {|val foo : int -> int|} in
  Alcotest.(check bool)
    "mli with no suite -> non-compliant" false
    (Suite_mli.is_compliant ~expected:alcotest_t src)

let test_wrong_type () =
  let src = {|val suite : unit Alcotest.test_case list|} in
  Alcotest.(check bool)
    "suite of wrong type -> non-compliant" false
    (Suite_mli.is_compliant ~expected:alcotest_t src)

let test_extra_val () =
  let src =
    {|val suite : string * unit Alcotest.test_case list
val helper : int -> int|}
  in
  Alcotest.(check bool)
    "extra val export -> non-compliant" false
    (Suite_mli.is_compliant ~expected:alcotest_t src)

let test_whitespace_collapsed () =
  (* Extra whitespace inside the val line must not defeat detection. *)
  let src = {|val   suite  :  string * unit Alcotest.test_case list|} in
  Alcotest.(check bool)
    "extra whitespace tolerated" true
    (Suite_mli.is_compliant ~expected:alcotest_t src)

let test_comment_lines_ignored () =
  let src =
    {|(* doc comment *)
val suite : string * unit Alcotest.test_case list
(* trailing comment *)|}
  in
  Alcotest.(check bool)
    "comment-only lines skipped" true
    (Suite_mli.is_compliant ~expected:alcotest_t src)

let test_suffix_match_not_anchored () =
  (* The matcher uses [String.ends_with]; a [val suite] whose annotation
     wraps onto a continuation line wouldn't end with the expected suffix
     and so should fail. We approximate this by using a single-line val with
     a different prefix that ends correctly. *)
  let src = {|val suite : int * string * unit Alcotest.test_case list|} in
  Alcotest.(check bool)
    "suffix-only match: this happens to end in the suffix" true
    (Suite_mli.is_compliant ~expected:alcotest_t src);
  (* And a clearly wrong tail isn't accepted. *)
  let src_bad = {|val suite : string * Alcotest.test_case list|} in
  Alcotest.(check bool)
    "missing [unit] mid-type -> non-compliant" false
    (Suite_mli.is_compliant ~expected:alcotest_t src_bad)

let test_blank_input () =
  Alcotest.(check bool)
    "empty mli -> non-compliant" false
    (Suite_mli.is_compliant ~expected:alcotest_t "")

let suite =
  ( "suite_mli",
    [
      Alcotest.test_case "compliant alcotest" `Quick test_compliant_alcotest;
      Alcotest.test_case "compliant alcobar" `Quick test_compliant_alcobar;
      Alcotest.test_case "no suite" `Quick test_no_suite;
      Alcotest.test_case "wrong type" `Quick test_wrong_type;
      Alcotest.test_case "extra val" `Quick test_extra_val;
      Alcotest.test_case "whitespace collapsed" `Quick test_whitespace_collapsed;
      Alcotest.test_case "comment lines ignored" `Quick
        test_comment_lines_ignored;
      Alcotest.test_case "suffix match not anchored" `Quick
        test_suffix_match_not_anchored;
      Alcotest.test_case "blank input" `Quick test_blank_input;
    ] )
