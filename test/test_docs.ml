(** Tests for documentation style checking *)

open Merlint

let test_function_doc_good () =
  let issues =
    Docs.check_function_doc ~name:"foo" ~doc:"[foo x] computes the foo of x."
  in
  Alcotest.(
    check
      (list
         (module struct
           type t = Docs.style_issue

           let pp = Docs.pp_style_issue
           let equal = ( = )
         end)))
    "no issues" [] issues

let test_function_doc_missing_brackets () =
  let issues =
    Docs.check_function_doc ~name:"bar" ~doc:"Computes the bar value."
  in
  Alcotest.(check bool)
    "has bad format issue"
    (List.mem Docs.Bad_function_format issues)
    true

let test_function_doc_missing_period () =
  let issues =
    Docs.check_function_doc ~name:"baz" ~doc:"[baz x] returns the baz of x"
  in
  Alcotest.(check bool)
    "has missing period issue"
    (List.mem Docs.Missing_period issues)
    true

let test_function_doc_redundant_phrase () =
  let issues =
    Docs.check_function_doc ~name:"qux" ~doc:"This function computes qux."
  in
  Alcotest.(check bool)
    "has redundant phrase issue"
    (List.exists
       (function Docs.Redundant_phrase _ -> true | _ -> false)
       issues)
    true

let test_type_doc_good () =
  let issues = Docs.check_type_doc ~doc:"The type for users." in
  Alcotest.(
    check
      (list
         (module struct
           type t = Docs.style_issue

           let pp = Docs.pp_style_issue
           let equal = ( = )
         end)))
    "no issues" [] issues

let test_type_doc_missing_period () =
  let issues = Docs.check_type_doc ~doc:"User information" in
  Alcotest.(check bool)
    "has missing period issue"
    (List.mem Docs.Missing_period issues)
    true

let test_type_doc_redundant_phrase () =
  let issues = Docs.check_type_doc ~doc:"This type represents users." in
  Alcotest.(check bool)
    "has redundant phrase issue"
    (List.exists
       (function Docs.Redundant_phrase _ -> true | _ -> false)
       issues)
    true

let test_value_doc_good () =
  let issues = Docs.check_value_doc ~name:"debug" ~doc:"Enable debug mode." in
  Alcotest.(
    check
      (list
         (module struct
           type t = Docs.style_issue

           let pp = Docs.pp_style_issue
           let equal = ( = )
         end)))
    "no issues" [] issues

let test_value_doc_missing_period () =
  let issues =
    Docs.check_value_doc ~name:"verbose" ~doc:"Verbose output flag"
  in
  Alcotest.(check bool)
    "has missing period issue"
    (List.mem Docs.Missing_period issues)
    true

let suite =
  [
    ("function doc - good style", `Quick, test_function_doc_good);
    ( "function doc - missing brackets",
      `Quick,
      test_function_doc_missing_brackets );
    ("function doc - missing period", `Quick, test_function_doc_missing_period);
    ( "function doc - redundant phrase",
      `Quick,
      test_function_doc_redundant_phrase );
    ("type doc - good style", `Quick, test_type_doc_good);
    ("type doc - missing period", `Quick, test_type_doc_missing_period);
    ("type doc - redundant phrase", `Quick, test_type_doc_redundant_phrase);
    ("value doc - good style", `Quick, test_value_doc_good);
    ("value doc - missing period", `Quick, test_value_doc_missing_period);
  ]
