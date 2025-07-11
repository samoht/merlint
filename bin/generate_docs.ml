open Merlint

let get_base_styles () =
  {|body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    color: #333;
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
    background: #f8f9fa;
}
h1 {
    color: #2c3e50;
    border-bottom: 3px solid #3498db;
    padding-bottom: 10px;
}
h2 {
    color: #34495e;
    margin-top: 40px;
    border-bottom: 1px solid #bdc3c7;
    padding-bottom: 8px;
}|}

let get_card_styles () =
  {|.error-card {
    background: white;
    border: 1px solid #ddd;
    border-radius: 8px;
    padding: 20px;
    margin: 20px 0;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
.error-code {
    font-family: 'Courier New', monospace;
    font-size: 1.2em;
    font-weight: bold;
    color: #e74c3c;
    display: inline-block;
    background: #fee;
    padding: 4px 8px;
    border-radius: 4px;
    margin-right: 10px;
}
.error-title {
    font-size: 1.1em;
    font-weight: bold;
    color: #2c3e50;
    display: inline-block;
}
.error-hint {
    margin-top: 15px;
    padding: 15px;
    background: #f0f8ff;
    border-left: 4px solid #3498db;
    border-radius: 4px;
    white-space: pre-wrap;
}|}

let get_example_styles () =
  {|.code-example {
    background: #f5f5f5;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 10px;
    margin: 10px 0;
    overflow-x: auto;
    font-family: 'Courier New', monospace;
    font-size: 0.9em;
}
.bad-example {
    color: #e74c3c;
    font-weight: bold;
}
.good-example {
    color: #27ae60;
    font-weight: bold;
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
.toc ul {
    list-style-type: none;
    padding-left: 20px;
}
.toc a {
    color: #3498db;
    text-decoration: none;
}
.toc a:hover {
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
}
.back-to-top:hover {
    opacity: 1;
}|}

let get_html_style () =
  String.concat "\n"
    [
      get_base_styles ();
      get_card_styles ();
      get_example_styles ();
      get_nav_styles ();
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

(* Get all issue types in order *)
let all_issue_types =
  [
    (* Complexity *)
    Issue_type.Complexity;
    Issue_type.Function_length;
    Issue_type.Deep_nesting;
    (* Security/Safety *)
    Issue_type.Obj_magic;
    Issue_type.Catch_all_exception;
    Issue_type.Silenced_warning;
    (* Style/Modernization *)
    Issue_type.Str_module;
    Issue_type.Printf_module;
    (* Naming Conventions *)
    Issue_type.Variant_naming;
    Issue_type.Module_naming;
    Issue_type.Value_naming;
    Issue_type.Type_naming;
    Issue_type.Long_identifier;
    Issue_type.Function_naming;
    Issue_type.Redundant_module_name;
    (* Documentation *)
    Issue_type.Missing_mli_doc;
    Issue_type.Missing_value_doc;
    Issue_type.Bad_doc_style;
    Issue_type.Missing_standard_function;
    (* Project Structure *)
    Issue_type.Missing_ocamlformat_file;
    Issue_type.Missing_mli_file;
    (* Testing *)
    Issue_type.Test_exports_module;
    Issue_type.Missing_test_file;
    Issue_type.Test_without_library;
    Issue_type.Test_suite_not_included;
  ]

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
        let formatted =
          List.map
            (fun ex ->
              let label = if ex.Hints.is_good then "GOOD" else "BAD" in
              let desc =
                match ex.description with
                | None -> ""
                | Some d -> Fmt.str "<p class=\"example-description\">%s</p>" d
              in
              Fmt.str
                {|<div class="example %s">
  <h4>%s</h4>
  %s
  <pre><code class="language-ocaml">%s</code></pre>
</div>|}
                (if ex.is_good then "good" else "bad")
                label desc ex.code)
            examples
        in
        "\n" ^ String.concat "\n" formatted
  in
  Fmt.str "<p>%s</p>%s" hint.text example_html

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
    if Array.length Sys.argv > 1 then Sys.argv.(1) else "error-codes.html"
  in

  (* Generate and write HTML *)
  let html = generate_html () in
  let oc = open_out output_path in
  output_string oc html;
  close_out oc;

  Fmt.pr "Generated %s with %d error codes@." output_path
    (List.length all_issue_types)
