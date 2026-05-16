(** Tests for the Doc module. *)

let sample_rule =
  Merlint.Rule.v ~code:"E215" ~title:"Prefer failwith helper"
    ~category:Merlint.Rule.Style_modernization
    ~hint:"Use the direct helper instead of formatting first."
    ~examples:[ { is_good = true; code = "failwith \"bad\"" } ]
    ~pp:Fmt.nop
    (Merlint.Rule.File (fun _ -> []))

let pp_format ppf = function
  | Merlint.Doc.Text -> Fmt.string ppf "text"
  | Merlint.Doc.Markdown -> Fmt.string ppf "markdown"
  | Merlint.Doc.Html -> Fmt.string ppf "html"

let format = Alcotest.testable pp_format ( = )

let is_infix ~affix s =
  let affix_len = String.length affix in
  let len = String.length s in
  let rec loop i =
    if i + affix_len > len then false
    else if String.sub s i affix_len = affix then true
    else loop (i + 1)
  in
  loop 0

let test_format_of_string () =
  Alcotest.(check (result format string))
    "markdown alias" (Ok Merlint.Doc.Markdown)
    (Merlint.Doc.format_of_string "md");
  Alcotest.(check (result format string))
    "html" (Ok Merlint.Doc.Html)
    (Merlint.Doc.format_of_string "html");
  match Merlint.Doc.format_of_string "json" with
  | Ok _ -> Alcotest.fail "unknown format should fail"
  | Error msg ->
      Alcotest.(check string)
        "error message" "unknown format \"json\" (expected: text, md, html)" msg

let test_render_rule_text () =
  let rendered = Merlint.Doc.render_rule ~format:Merlint.Doc.Text sample_rule in
  Alcotest.(check bool)
    "contains code and title" true
    (String.contains rendered '['
    && String.contains rendered ']'
    && is_infix ~affix:"Prefer failwith helper" rendered);
  Alcotest.(check bool)
    "contains example" true
    (is_infix ~affix:"Examples:" rendered)

let test_render_rule_markdown () =
  let rendered =
    Merlint.Doc.render_rule ~format:Merlint.Doc.Markdown sample_rule
  in
  Alcotest.(check bool)
    "heading" true
    (String.starts_with ~prefix:"### [E215] Prefer failwith helper" rendered);
  Alcotest.(check bool) "code fence" true (is_infix ~affix:"```ocaml" rendered)

let test_render_index () =
  let rendered = Merlint.Doc.render_index [ sample_rule ] in
  Alcotest.(check bool)
    "one-line index includes rule" true
    (is_infix ~affix:"E215" rendered
    && is_infix ~affix:"Prefer failwith helper" rendered)

let tests =
  [
    Alcotest.test_case "format_of_string" `Quick test_format_of_string;
    Alcotest.test_case "render rule text" `Quick test_render_rule_text;
    Alcotest.test_case "render rule markdown" `Quick test_render_rule_markdown;
    Alcotest.test_case "render index" `Quick test_render_index;
  ]

let suite = ("doc", tests)
