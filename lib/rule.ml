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

let by_category rules =
  let by_cat = Hashtbl.create 7 in
  List.iter
    (fun rule ->
      let existing =
        match Hashtbl.find_opt by_cat rule.category with
        | Some rs -> rs
        | None -> []
      in
      Hashtbl.replace by_cat rule.category (rule :: existing))
    rules;

  (* Return in a stable order *)
  [
    Complexity;
    Security_safety;
    Style_modernization;
    Naming_conventions;
    Documentation;
    Project_structure;
    Testing;
  ]
  |> List.map (fun cat ->
         let rules_in_cat =
           match Hashtbl.find_opt by_cat cat with
           | Some rs -> List.rev rs (* Reverse to maintain order *)
           | None -> []
         in
         (cat, rules_in_cat))

let category_to_string = function
  | Complexity -> "Complexity"
  | Security_safety -> "Security/Safety"
  | Style_modernization -> "Style/Modernization"
  | Naming_conventions -> "Naming Conventions"
  | Documentation -> "Documentation"
  | Project_structure -> "Project Structure"
  | Testing -> "Testing"

let category_description = function
  | Complexity -> "Code complexity and maintainability issues"
  | Security_safety ->
      "Potential security vulnerabilities and unsafe code patterns"
  | Style_modernization -> "Code style and modernization recommendations"
  | Naming_conventions -> "Identifier naming convention violations"
  | Documentation -> "Missing or incorrect documentation"
  | Project_structure -> "Project organization and configuration issues"
  | Testing -> "Test coverage and test quality issues"

let category_range = function
  | Complexity -> "E001-E099"
  | Security_safety -> "E100-E199"
  | Style_modernization -> "E200-E299"
  | Naming_conventions -> "E300-E399"
  | Documentation -> "E400-E499"
  | Project_structure -> "E500-E599"
  | Testing -> "E600-E699"
