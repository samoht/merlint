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

type 'a scope =
  | File of (Context.file -> 'a Issue.t list)
  | Project of (Context.project -> 'a Issue.t list)

type 'a desc = {
  code : string;
  title : string;
  category : category;
  hint : string;
  examples : example list;
  check : 'a scope;
  pp : 'a Fmt.t;
}

type t = T : _ desc -> t

let v ~code ~title ~category ~hint ?(examples = []) ~pp check =
  T { code; title; category; hint; examples; check; pp }

(* Accessors *)
let code (T r) = r.code
let title (T r) = r.title
let category (T r) = r.category
let hint (T r) = r.hint
let examples (T r) = r.examples

let category_name = function
  | Complexity -> "Code Quality"
  | Security_safety -> "Code Quality"
  | Style_modernization -> "Code Style"
  | Naming_conventions -> "Naming Conventions"
  | Documentation -> "Documentation"
  | Project_structure -> "Project Structure"
  | Testing -> "Test Quality"

let is_file_scoped (T desc) =
  match desc.check with File _ -> true | Project _ -> false

let is_project_scoped (T desc) =
  match desc.check with Project _ -> true | File _ -> false

(* Module for handling rule execution results *)
module Run = struct
  type result = Result : string * string * 'a Fmt.t * 'a Issue.t -> result

  let file (T desc) ctx =
    match desc.check with
    | File check_fn ->
        let issues = check_fn ctx in
        List.map
          (fun issue -> Result (desc.code, desc.title, desc.pp, issue))
          issues
    | Project _ -> []

  let project (T desc) ctx =
    match desc.check with
    | Project check_fn ->
        let issues = check_fn ctx in
        List.map
          (fun issue -> Result (desc.code, desc.title, desc.pp, issue))
          issues
    | File _ -> []

  let code (Result (c, _, _, _)) = c
  let title (Result (_, t, _, _)) = t
  let pp ppf (Result (_, _, fmt, issue)) = Issue.pp fmt ppf issue
  let location (Result (_, _, _, issue)) = Issue.location issue

  let compare (Result (_, _, _, a)) (Result (_, _, _, b)) =
    match (Issue.location a, Issue.location b) with
    | None, None -> 0
    | None, Some _ -> -1
    | Some _, None -> 1
    | Some a_loc, Some b_loc -> Location.compare a_loc b_loc
end
