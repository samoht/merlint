(** Linting rule definitions and registry *)

type category =
  | Complexity
  | Security_safety
  | Style_modernization
  | Naming_conventions
  | Documentation
  | Project_structure
  | Testing
  | Interop_testing
  | Code_generation

type example = { is_good : bool; code : string }

type 'a scope =
  | File of (Context.file -> 'a Issue.t list)
  | Project of (Context.project -> 'a Issue.t list)
  | Project_units : {
      enumerate : Context.project -> 'unit list;
      check : Context.project -> 'unit -> 'a Issue.t list;
    }
      -> 'a scope

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
  | Interop_testing -> "Interop Testing"
  | Code_generation -> "Code Generation"

let is_file_scoped (T desc) =
  match desc.check with File _ -> true | Project _ | Project_units _ -> false

let is_project_scoped (T desc) =
  match desc.check with Project _ | Project_units _ -> true | File _ -> false

let equal (T desc1) (T desc2) = desc1.code = desc2.code
let pp ppf (T desc) = Fmt.pf ppf "[%s] %s" desc.code desc.title

(* Module for handling rule execution results *)
module Run = struct
  type result = Result : string * string * 'a Fmt.t * 'a Issue.t -> result

  type project_job =
    | Job : {
        code : string;
        title : string;
        pp : 'a Fmt.t;
        run : unit -> 'a Issue.t list;
      }
        -> project_job

  let file (T desc) ctx =
    match desc.check with
    | File check_fn ->
        let issues = check_fn ctx in
        List.map
          (fun issue -> Result (desc.code, desc.title, desc.pp, issue))
          issues
    | Project _ | Project_units _ -> []

  let project_jobs (T desc) ctx =
    match desc.check with
    | Project check_fn ->
        [
          Job
            {
              code = desc.code;
              title = desc.title;
              pp = desc.pp;
              run = (fun () -> check_fn ctx);
            };
        ]
    | Project_units { enumerate; check } ->
        List.map
          (fun unit ->
            Job
              {
                code = desc.code;
                title = desc.title;
                pp = desc.pp;
                run = (fun () -> check ctx unit);
              })
          (enumerate ctx)
    | File _ -> []

  let project_job (Job { code; title; pp; run }) =
    List.map (fun issue -> Result (code, title, pp, issue)) (run ())

  let project (T desc) ctx =
    project_jobs (T desc) ctx |> List.concat_map project_job

  let project_job_code (Job { code; _ }) = code
  let code (Result (c, _, _, _)) = c
  let title (Result (_, t, _, _)) = t
  let pp ppf (Result (_, _, fmt, issue)) = Issue.pp fmt ppf issue
  let location (Result (_, _, _, issue)) = Issue.location issue

  let compare (Result (_, _, _, a)) (Result (_, _, _, b)) =
    match Int.compare (Issue.severity b) (Issue.severity a) with
    | 0 -> (
        match (Issue.location a, Issue.location b) with
        | None, None -> 0
        | None, Some _ -> -1
        | Some _, None -> 1
        | Some a_loc, Some b_loc -> Location.compare a_loc b_loc)
    | c -> c
end
