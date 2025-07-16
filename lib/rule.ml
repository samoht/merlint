(** Linting rule definitions and registry *)

type category =
  | Complexity
  | Security_safety
  | Style_modernization
  | Naming_conventions
  | Documentation
  | Project_structure
  | Testing

type example = { is_good : bool; code : string }

let good code = { is_good = true; code }
let bad code = { is_good = false; code }

type code_example = {
  is_good : bool;
  description : string option;
  code : string;
}

type hint = { text : string; examples : code_example list option }
type scope = File | Project

type t = {
  issue : Issue_type.t;
  title : string;
  category : category;
  scope : scope;
  hint : string;
  examples : example list;
}

let v ~issue ~title ~category ?(scope = File) ?(examples = []) hint =
  { issue; title; category; scope; hint; examples }

let get rules issue_type =
  match List.find_opt (fun rule -> rule.issue = issue_type) rules with
  | Some rule -> rule
  | None -> failwith (Fmt.str "No rule found for issue type")

let category_name = function
  | Complexity -> "Code Quality"
  | Security_safety -> "Code Style"
  | Style_modernization -> "Code Style"
  | Naming_conventions -> "Naming Conventions"
  | Documentation -> "Documentation"
  | Project_structure -> "Project Structure"
  | Testing -> "Test Quality"

(** Get a short title for a specific issue type *)
let get_hint_title rules issue_type =
  let rule = get rules issue_type in
  rule.title

(** Get a structured hint with text and optional code examples *)
let get_structured_hint rules issue_type =
  let rule = get rules issue_type in
  let examples =
    match rule.examples with
    | [] -> None
    | exs ->
        Some
          (List.map
             (fun (ex : example) ->
               { is_good = ex.is_good; description = None; code = ex.code })
             exs)
  in
  { text = rule.hint; examples }

(** Get a hint for a specific issue type *)
let get_hint rules issue_type =
  let hint = get_structured_hint rules issue_type in
  hint.text
