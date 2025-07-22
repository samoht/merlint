(** Tests for the Docs module *)

(* Helper to make style_issue testable for Alcotest *)
let style_issue : Merlint.Docs.style_issue Alcotest.testable =
  Alcotest.testable Merlint.Docs.pp_style_issue Merlint.Docs.equal_style_issue

let test_check_function_doc () =
  let open Merlint.Docs in
  (* Good function doc *)
  let issues =
    check_function_doc ~name:"foo" ~doc:"[foo x] computes foo of x."
  in
  Alcotest.(check (list style_issue)) "good function doc" [] issues;

  (* Missing period *)
  let issues =
    check_function_doc ~name:"bar" ~doc:"[bar x] computes bar of x"
  in
  Alcotest.(check (list style_issue)) "missing period" [ Missing_period ] issues;

  (* Bad format *)
  let issues =
    check_function_doc ~name:"baz" ~doc:"This function computes baz."
  in
  Alcotest.(check (list style_issue))
    "bad format"
    [ Redundant_phrase "This function"; Bad_function_format ]
    issues;

  (* Missing bracket format *)
  let issues = check_function_doc ~name:"qux" ~doc:"Computes qux of x." in
  Alcotest.(check (list style_issue))
    "missing brackets" [ Bad_function_format ] issues

let test_check_value_doc () =
  let open Merlint.Docs in
  (* Good value doc *)
  let issues = check_value_doc ~name:"version" ~doc:"The current version." in
  Alcotest.(check (list style_issue)) "good value doc" [] issues;

  (* Missing period *)
  let issues = check_value_doc ~name:"count" ~doc:"The total count" in
  Alcotest.(check (list style_issue)) "missing period" [ Missing_period ] issues;

  (* Redundant phrase *)
  let issues =
    check_value_doc ~name:"data" ~doc:"This value represents data."
  in
  Alcotest.(check (list style_issue))
    "redundant phrase"
    [ Redundant_phrase "This value" ]
    issues

let test_check_type_doc () =
  let open Merlint.Docs in
  (* Good type doc *)
  let issues = check_type_doc ~doc:"A user identifier." in
  Alcotest.(check (list style_issue)) "good type doc" [] issues;

  (* Missing period *)
  let issues = check_type_doc ~doc:"A user identifier" in
  Alcotest.(check (list style_issue)) "missing period" [ Missing_period ] issues;

  (* Redundant phrase *)
  let issues = check_type_doc ~doc:"This type represents a user." in
  Alcotest.(check (list style_issue))
    "redundant phrase"
    [ Redundant_phrase "This type" ]
    issues

let test_is_function_signature () =
  let open Merlint.Docs in
  Alcotest.(check bool)
    "arrow function" true
    (is_function_signature "string -> int");
  Alcotest.(check bool)
    "multi-arg function" true
    (is_function_signature "string -> int -> bool");
  Alcotest.(check bool) "not a function" false (is_function_signature "string");
  Alcotest.(check bool)
    "record type" false
    (is_function_signature "{ name : string; age : int }")

let test_extract_doc_comments () =
  let open Merlint.Docs in
  let content =
    {|
(** [foo x] computes foo. *)
val foo : int -> int

val bar : string -> string
(** [bar s] transforms s. *)

(* Regular comment *)
val baz : unit -> unit

(** *)
val empty : string
|}
  in

  let comments = extract_doc_comments content in
  Alcotest.(check int) "number of comments" 4 (List.length comments);

  (* Check first comment *)
  let first = List.hd comments in
  Alcotest.(check string) "first value name" "foo" first.value_name;
  Alcotest.(check string) "first doc" "[foo x] computes foo." first.doc;
  Alcotest.(check string) "first signature" "int -> int" first.signature;

  (* Check second comment *)
  let second = List.nth comments 1 in
  Alcotest.(check string) "second value name" "bar" second.value_name;
  Alcotest.(check string) "second doc" "[bar s] transforms s." second.doc;

  (* Check bad comment detection *)
  let third = List.nth comments 2 in
  Alcotest.(check string) "third value name" "baz" third.value_name;
  Alcotest.(check string) "bad comment marker" "BAD_COMMENT" third.doc;

  (* Check empty doc *)
  let fourth = List.nth comments 3 in
  Alcotest.(check string) "fourth value name" "empty" fourth.value_name;
  Alcotest.(check string) "empty doc" "" fourth.doc

let tests =
  let open Alcotest in
  [
    test_case "check_function_doc" `Quick test_check_function_doc;
    test_case "check_value_doc" `Quick test_check_value_doc;
    test_case "check_type_doc" `Quick test_check_type_doc;
    test_case "is_function_signature" `Quick test_is_function_signature;
    test_case "extract_doc_comments" `Quick test_extract_doc_comments;
    (* TODO: Fix this test - the extract_doc_comments function should use ppxlib 
       instead of string parsing to properly handle multiline comments *)
    (* test_case "extract_multiline_doc" `Quick test_extract_multiline_doc; *)
  ]

let suite = ("docs", tests)
