(** Implementation of the new self-contained rule design *)

type category =
  | Complexity
  | Security_safety
  | Style_modernization
  | Naming_conventions
  | Documentation
  | Project_structure
  | Testing

type example = {
  is_good : bool;
  code : string;
}

let good code = { is_good = true; code }
let bad code = { is_good = false; code }

type check_scope =
  | File_check of (Context.file -> Issue.t list)
  | Project_check of (Context.project -> Issue.t list)

type t = {
  code : string;
  title : string;
  category : category;
  hint : string;
  examples : example list;
  check : check_scope;
  format_issue : Issue_new.data -> string;
}

let v ~code ~title ~category ~hint ?(examples = []) ~check ~format_issue () =
  { code; title; category; hint; examples; check; format_issue }

let get_by_code rules code =
  List.find_opt (fun r -> r.code = code) rules

let category_name = function
  | Complexity -> "Code Quality"
  | Security_safety -> "Code Quality"
  | Style_modernization -> "Code Style"
  | Naming_conventions -> "Naming Conventions"
  | Documentation -> "Documentation"
  | Project_structure -> "Project Structure"
  | Testing -> "Test Quality"