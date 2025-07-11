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
  let rule = Rule.get Data.all_rules issue_type in
  rule.title

(** Get a structured hint with text and optional code examples *)
let get_structured_hint issue_type =
  let rule = Rule.get Data.all_rules issue_type in
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
