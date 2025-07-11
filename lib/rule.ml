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

type t = {
  issue : Issue_type.t;
  title : string;
  category : category;
  hint : string;
  examples : example list;
}

let v ~issue ~title ~category ?(examples = []) hint =
  { issue; title; category; hint; examples }

let get rules issue_type =
  match List.find_opt (fun rule -> rule.issue = issue_type) rules with
  | Some rule -> rule
  | None -> failwith (Fmt.str "No rule found for issue type")
