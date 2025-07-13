open Merlint

let get_body_styles () =
  {|body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    color: #333;
    max-width: 1400px;
    margin: 0 auto;
    padding: 20px;
    background: #f8f9fa;
}|}

let get_heading_styles () =
  {|h1 {
    color: #2c3e50;
    border-bottom: 3px solid #3498db;
    padding-bottom: 10px;
    margin-bottom: 30px;
}
h2 {
    color: #34495e;
    margin-top: 40px;
    margin-bottom: 20px;
    border-bottom: 1px solid #bdc3c7;
    padding-bottom: 8px;
}|}

let get_text_styles () =
  {|p {
    margin: 1em 0;
    line-height: 1.7;
}
code {
    background-color: #f4f4f4;
    padding: 2px 4px;
    border-radius: 3px;
    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
    font-size: 0.9em;
    color: #e83e8c;
}
pre {
    background-color: #f8f8f8;
    color: #333;
    padding: 12px 16px;
    border-radius: 6px;
    overflow-x: auto;
    margin: 0.5em 0;
    border: 1px solid #e1e4e8;
}
pre code {
    background-color: transparent;
    color: inherit;
    padding: 0;
    font-size: 0.875em;
    line-height: 1.5;
    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
    white-space: pre;
}|}

let get_card_styles () =
  {|.error-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 18px 20px;
    margin: 16px 0;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    max-width: 1400px;
}
.error-code {
    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
    font-size: 1.1em;
    font-weight: bold;
    color: #dc2626;
    display: inline-block;
    background: #fee;
    padding: 3px 8px;
    border-radius: 4px;
    margin-right: 10px;
}
.error-title {
    font-size: 1.05em;
    font-weight: 600;
    color: #1f2937;
    display: inline-block;
}
.error-hint {
    margin-top: 12px;
    padding: 0;
}
.error-hint > p {
    padding: 12px 16px;
    background: #eff6ff;
    border-left: 4px solid #3b82f6;
    border-radius: 0 4px 4px 0;
    margin: 0 0 12px 0;
    line-height: 1.6;
    color: #1e40af;
}|}

let get_example_grid_styles () =
  {|.examples-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
    margin: 20px 0;
}
@media (max-width: 968px) {
    .examples-grid {
        grid-template-columns: 1fr;
    }
}|}

let get_example_box_styles () =
  {|.example {
    border-radius: 6px;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}
.example.bad {
    border: 1px solid #fecaca;
    background-color: #fef2f2;
}
.example.good {
    border: 1px solid #bbf7d0;
    background-color: #f0fdf4;
}
.example h4 {
    margin: 0;
    padding: 8px 12px;
    font-size: 0.8em;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}
.example.bad h4 {
    background-color: #fecaca;
    color: #991b1b;
}
.example.good h4 {
    background-color: #bbf7d0;
    color: #14532d;
}|}

let get_example_content_styles () =
  {|.example-description {
    padding: 8px 12px;
    margin: 0;
    color: #4b5563;
    font-size: 0.9em;
    line-height: 1.5;
}
.example pre {
    margin: 0;
    padding: 12px 16px;
    border-radius: 0;
    border-top: 1px solid rgba(0,0,0,0.1);
    background-color: #f8f8f8;
    font-size: 0.85em;
    overflow-x: auto;
}
.example.bad pre {
    background-color: #fffafa;
}
.example.good pre {
    background-color: #f8fffe;
}
.example pre code {
    background-color: transparent;
    color: #333;
    padding: 0;
}
.category {
    color: #7f8c8d;
    font-size: 0.9em;
    margin-bottom: 20px;
}|}

let get_nav_styles () =
  {|.toc {
    background: white;
    border: 1px solid #ddd;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 30px;
}
.toc h2 {
    margin-top: 0;
    margin-bottom: 15px;
    border: none;
    padding-bottom: 0;
}
.toc ul {
    list-style-type: none;
    padding-left: 0;
    margin: 0;
}
.toc li {
    margin: 8px 0;
}
.toc a {
    color: #3498db;
    text-decoration: none;
    display: block;
    padding: 4px 0;
    transition: color 0.2s ease;
}
.toc a:hover {
    color: #2980b9;
    text-decoration: underline;
}
.back-to-top {
    position: fixed;
    bottom: 20px;
    right: 20px;
    background: #3498db;
    color: white;
    padding: 10px 15px;
    border-radius: 5px;
    text-decoration: none;
    opacity: 0.8;
    transition: opacity 0.2s ease;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
}
.back-to-top:hover {
    opacity: 1;
}|}

(* Helper functions for syntax highlighting *)
let html_escape s =
  s |> String.split_on_char '&' |> String.concat "&amp;"
  |> String.split_on_char '<' |> String.concat "&lt;"
  |> String.split_on_char '>' |> String.concat "&gt;"
  |> String.split_on_char '"' |> String.concat "&quot;"

let ocaml_keywords =
  [
    "let";
    "in";
    "if";
    "then";
    "else";
    "match";
    "with";
    "fun";
    "function";
    "try";
    "type";
    "module";
    "open";
    "and";
    "or";
    "not";
    "rec";
    "when";
    "as";
    "of";
    "begin";
    "end";
    "struct";
    "sig";
    "val";
    "include";
    "for";
    "while";
    "do";
    "done";
    "to";
    "ref";
    "mutable";
    "new";
    "class";
    "object";
    "method";
    "inherit";
    "external";
    "exception";
    "raise";
    "assert";
    "lazy";
    "true";
    "false";
  ]

let add_pattern_segments pattern class_name escaped segments =
  let re = Re.Perl.compile_pat pattern in
  Re.all re escaped
  |> List.iter (fun g ->
         let start = Re.Group.start g 0 in
         let stop = Re.Group.stop g 0 in
         let text = Re.Group.get g 0 in
         segments := (start, stop, class_name, text) :: !segments)

let add_keyword_segments escaped segments =
  List.iter
    (fun kw ->
      let pattern = Re.Perl.compile_pat (Fmt.str {|\b%s\b|} kw) in
      Re.all pattern escaped
      |> List.iter (fun g ->
             let start = Re.Group.start g 0 in
             let stop = Re.Group.stop g 0 in
             segments := (start, stop, "kw", kw) :: !segments))
    ocaml_keywords

let remove_overlapping_segments segments =
  let sorted_segments =
    List.sort (fun (s1, _, _, _) (s2, _, _, _) -> compare s1 s2) segments
  in
  let non_overlapping = ref [] in
  let last_end = ref (-1) in
  List.iter
    (fun (start, stop, class_name, text) ->
      if start >= !last_end then (
        non_overlapping := (start, stop, class_name, text) :: !non_overlapping;
        last_end := stop))
    sorted_segments;
  List.rev !non_overlapping

let build_highlighted_text escaped segments =
  let result = ref "" in
  let last_pos = ref 0 in

  List.iter
    (fun (start, stop, class_name, text) ->
      (* Add unprocessed text before this segment *)
      if start > !last_pos then
        result := !result ^ String.sub escaped !last_pos (start - !last_pos);

      (* Add the highlighted segment *)
      if class_name = "module_path" then
        (* Special handling for module paths *)
        let parts = String.split_on_char '.' text in
        match parts with
        | [ m; f ] ->
            result :=
              !result
              ^ Fmt.str
                  {|<span class="md">%s</span>.<span class="fn">%s</span>|} m f
        | _ -> result := !result ^ text
      else
        result :=
          !result ^ Fmt.str {|<span class="%s">%s</span>|} class_name text;

      last_pos := stop)
    segments;

  (* Add any remaining text *)
  if !last_pos < String.length escaped then
    result :=
      !result ^ String.sub escaped !last_pos (String.length escaped - !last_pos);

  !result

(* Simple but effective OCaml syntax highlighting *)
let highlight_ocaml_code code =
  (* Process each line to preserve structure *)
  let process_line line =
    let escaped = html_escape line in

    (* Build a list of segments with their positions *)
    let segments = ref [] in

    (* Find comments *)
    add_pattern_segments {|\(\*.*?\*\)|} "cm" escaped segments;

    (* Find strings *)
    add_pattern_segments {|"(?:[^"\\]|\\.)*"|} "st" escaped segments;

    (* Find numbers *)
    add_pattern_segments {|\b[0-9]+\.?[0-9]*\b|} "nu" escaped segments;

    (* Find keywords *)
    add_keyword_segments escaped segments;

    (* Find module paths *)
    add_pattern_segments {|\b[A-Z][a-zA-Z0-9_']*\.[a-z][a-zA-Z0-9_']*\b|}
      "module_path" escaped segments;

    (* Find constructors *)
    add_pattern_segments {|\b[A-Z][a-zA-Z0-9_']*\b|} "cn" escaped segments;

    (* Sort segments by start position and remove overlaps *)
    let segments = remove_overlapping_segments !segments in

    (* Build the final result *)
    build_highlighted_text escaped segments
  in

  code |> String.split_on_char '\n' |> List.map process_line
  |> String.concat "\n"

let get_syntax_highlighting_styles () =
  {|/* Additional styling */
.error-code {
    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
    font-size: 1.1em;
    font-weight: bold;
    color: #dc2626;
    display: inline-block;
    background: #fee;
    padding: 3px 8px;
    border-radius: 4px;
    margin-right: 10px;
}
.error-title {
    font-size: 1.05em;
    font-weight: 600;
    color: #1f2937;
    display: inline-block;
}

/* Syntax highlighting - minimal but effective */
.kw { color: #0000ff; font-weight: 600; }  /* keywords */
.st { color: #a31515; }  /* strings */
.cm { color: #008200; font-style: italic; }  /* comments */
.nu { color: #098658; }  /* numbers */
.cn { color: #267f99; }  /* constructors */
.md { color: #267f99; font-weight: 600; }  /* modules */
.fn { color: #795E26; }  /* functions */

/* Responsive design */
@media (max-width: 768px) {
    body {
        padding: 10px;
    }
    .error-card {
        padding: 15px;
    }
    pre {
        padding: 10px;
        font-size: 0.8em;
    }
}|}

let get_html_style () =
  String.concat "\n"
    [
      get_body_styles ();
      get_heading_styles ();
      get_text_styles ();
      get_card_styles ();
      get_example_grid_styles ();
      get_example_box_styles ();
      get_example_content_styles ();
      get_nav_styles ();
      get_syntax_highlighting_styles ();
    ]

let html_header =
  Fmt.str
    {|<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Merlint Error Codes Reference</title>
    <style>
%s
    </style>
</head>
<body>
|}
    (get_html_style ())

let html_footer =
  {|
    <a href="#top" class="back-to-top">↑ Top</a>
</body>
</html>
|}

(* Categories in order *)
let categories =
  [
    ("Complexity", "E001-E099", "Code complexity and maintainability issues");
    ( "Security/Safety",
      "E100-E199",
      "Potential security vulnerabilities and unsafe code patterns" );
    ( "Style/Modernization",
      "E200-E299",
      "Code style and modernization recommendations" );
    ( "Naming Conventions",
      "E300-E399",
      "Identifier naming convention violations" );
    ("Documentation", "E400-E499", "Missing or incorrect documentation");
    ( "Project Structure",
      "E500-E599",
      "Project organization and configuration issues" );
    ("Testing", "E600-E699", "Test coverage and test quality issues");
  ]

(* Get all issue types from the single source of truth *)
let all_issue_types = Issue_type.all

let get_category issue_type =
  let code = Issue_type.error_code issue_type in
  let code_num = int_of_string (String.sub code 1 (String.length code - 1)) in
  if code_num < 100 then "Complexity"
  else if code_num < 200 then "Security/Safety"
  else if code_num < 300 then "Style/Modernization"
  else if code_num < 400 then "Naming Conventions"
  else if code_num < 500 then "Documentation"
  else if code_num < 600 then "Project Structure"
  else "Testing"

let format_hint_html hint =
  let example_html =
    match hint.Hints.examples with
    | None -> ""
    | Some examples ->
        (* Separate good and bad examples *)
        let bad_examples =
          List.filter (fun ex -> not ex.Hints.is_good) examples
        in
        let good_examples = List.filter (fun ex -> ex.Hints.is_good) examples in
        let format_example ex =
          let label = if ex.Hints.is_good then "GOOD" else "BAD" in
          let desc =
            match ex.description with
            | None -> ""
            | Some d -> Fmt.str "<div class=\"example-description\">%s</div>" d
          in
          Fmt.str
            {|<div class="example %s">
  <h4>%s</h4>
  %s
  <pre><code>%s</code></pre>
</div>|}
            (if ex.is_good then "good" else "bad")
            label desc
            (highlight_ocaml_code ex.code)
        in
        (* Create grid if we have both good and bad examples *)
        if bad_examples <> [] && good_examples <> [] then
          let bad_html =
            String.concat "\n" (List.map format_example bad_examples)
          in
          let good_html =
            String.concat "\n" (List.map format_example good_examples)
          in
          Fmt.str {|<div class="examples-grid">
%s
%s
</div>|} bad_html
            good_html
        else
          (* Otherwise just show examples in sequence *)
          let all_formatted = List.map format_example examples in
          "\n" ^ String.concat "\n" all_formatted
  in
  (* Escape HTML in hint text *)
  let html_escape_text s =
    s |> String.split_on_char '&' |> String.concat "&amp;"
    |> String.split_on_char '<' |> String.concat "&lt;"
    |> String.split_on_char '>' |> String.concat "&gt;"
  in
  Fmt.str "<p>%s</p>%s" (html_escape_text hint.text) example_html

let generate_toc () =
  Fmt.str
    {|<div class="toc" id="top">
<h2>Table of Contents</h2>
<ul>
%s
</ul>
</div>|}
    (categories
    |> List.map (fun (name, range, _) ->
           Fmt.str {|<li><a href="#%s">%s (%s)</a></li>|}
             (String.lowercase_ascii name
             |> String.map (fun c -> if c = '/' then '-' else c))
             name range)
    |> String.concat "\n")

let generate_error_section issue_type =
  let code = Issue_type.error_code issue_type in
  let rule = Rule.get Data.all_rules issue_type in
  let title = rule.title in
  let hint = Hints.get_structured_hint issue_type in
  Fmt.str
    {|<div class="error-card" id="%s">
    <div>
        <span class="error-code">%s</span>
        <span class="error-title">%s</span>
    </div>
    <div class="error-hint">%s</div>
</div>|}
    code code title (format_hint_html hint)

let generate_category_section (name, range, description) =
  let category_id =
    String.lowercase_ascii name
    |> String.map (fun c -> if c = '/' then '-' else c)
  in
  let errors =
    all_issue_types
    |> List.filter (fun it -> get_category it = name)
    |> List.map generate_error_section
    |> String.concat "\n"
  in
  Fmt.str {|<h2 id="%s">%s</h2>
<div class="category">%s • %s</div>
%s|}
    category_id name range description errors

let generate_html () =
  let toc = generate_toc () in
  let content =
    categories |> List.map generate_category_section |> String.concat "\n"
  in
  Fmt.str
    {|%s
<h1>Merlint Error Codes Reference</h1>
<p>This document lists all error codes that Merlint can detect, along with their descriptions and fix hints.</p>
%s
%s
%s|}
    html_header toc content html_footer

let () =
  (* Get output path from command line or use default *)
  let output_path =
    if Array.length Sys.argv > 1 then Sys.argv.(1) else "index.html"
  in

  (* Generate and write HTML *)
  let html = generate_html () in
  let oc = open_out output_path in
  output_string oc html;
  close_out oc;

  Fmt.pr "Generated %s with %d error codes@." output_path
    (List.length all_issue_types)
