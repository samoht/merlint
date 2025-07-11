(** Hints for fixing different types of issues - wrapper around Rule module *)

type code_example = {
  is_good : bool;
  description : string option;
  code : string;
}
(** Re-export types from Rule module for backwards compatibility *)

type hint = { text : string; examples : code_example list option }

(** Get a short title for a specific issue type *)
let get_hint_title issue_type =
  let rule = Rule.find Data.all_rules issue_type in
  rule.title

(** Get a structured hint with text and optional code examples *)
let get_structured_hint issue_type =
  let rule = Rule.find Data.all_rules issue_type in
  let examples =
    match rule.examples with
    | [] -> None
    | exs ->
        Some
          (List.map
             (fun ex ->
               {
                 is_good = ex.Rule.is_good;
                 description = None;
                 code = ex.Rule.code;
               })
             exs)
  in
  { text = rule.hint; examples }

(** Get a hint for a specific issue type *)
let get_hint issue_type =
  let hint = get_structured_hint issue_type in
  hint.text

(** Format hint as plain text for CLI output *)
let format_hint_plain hint =
  let example_text =
    match hint.examples with
    | None -> ""
    | Some examples ->
        let formatted =
          List.map
            (fun ex ->
              let label = if ex.is_good then "GOOD" else "BAD" in
              Fmt.str "\n\n%s:\n%s" label ex.code)
            examples
        in
        String.concat "" formatted
  in
  hint.text ^ example_text

(** Format hint as HTML for web output *)
let format_hint_html hint =
  let example_html =
    match hint.examples with
    | None -> ""
    | Some examples ->
        let formatted =
          List.map
            (fun ex ->
              let label = if ex.is_good then "GOOD" else "BAD" in
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
