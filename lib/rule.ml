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

type 'a pass =
  | Pass : {
      select : Context.file -> bool;
      init : Context.file -> 'state;
      expr : ('state -> Ocaml_typing.Typedtree.expression -> unit) option;
      value_binding :
        ('state -> Ocaml_typing.Typedtree.value_binding -> unit) option;
      structure_item :
        ('state -> Ocaml_typing.Typedtree.structure_item -> unit) option;
      signature_item :
        ('state -> Ocaml_typing.Typedtree.signature_item -> unit) option;
      finish : Context.file -> 'state -> 'a Issue.t list;
    }
      -> 'a pass

type 'a scope =
  | File of (Context.file -> 'a Issue.t list)
  | Pass of 'a pass
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

let pass ?(select = fun _ -> true) ?expr ?value_binding ?structure_item
    ?signature_item ~init ~finish () =
  Pass
    (Pass
       { select; init; expr; value_binding; structure_item; signature_item; finish })

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
  match desc.check with
  | File _ | Pass _ -> true
  | Project _ | Project_units _ -> false

let is_direct_file_scoped (T desc) =
  match desc.check with
  | File _ -> true
  | Pass _ | Project _ | Project_units _ -> false

let uses_pass (T desc) =
  match desc.check with
  | Pass _ -> true
  | File _ | Project _ | Project_units _ -> false

let is_project_scoped (T desc) =
  match desc.check with
  | Project _ | Project_units _ -> true
  | File _ | Pass _ -> false

let equal (T desc1) (T desc2) = desc1.code = desc2.code
let pp ppf (T desc) = Fmt.pf ppf "[%s] %s" desc.code desc.title

(* Module for handling rule execution results *)
module Run = struct
  type result = Result : string * string * 'a Fmt.t * 'a Issue.t -> result

  type active_pass =
    | Active_pass : {
        code : string;
        title : string;
        pp : 'a Fmt.t;
        expr : (Ocaml_typing.Typedtree.expression -> unit) option;
        value_binding : (Ocaml_typing.Typedtree.value_binding -> unit) option;
        structure_item : (Ocaml_typing.Typedtree.structure_item -> unit) option;
        signature_item : (Ocaml_typing.Typedtree.signature_item -> unit) option;
        finish : unit -> 'a Issue.t list;
      }
        -> active_pass

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
    | Pass _ | Project _ | Project_units _ -> []

  let pass (T desc) ctx =
    match desc.check with
    | Pass (Pass pass) when pass.select ctx ->
        let state = pass.init ctx in
        Some
          (Active_pass
             {
               code = desc.code;
               title = desc.title;
               pp = desc.pp;
               expr = Option.map (fun f -> f state) pass.expr;
               value_binding = Option.map (fun f -> f state) pass.value_binding;
               structure_item =
                 Option.map (fun f -> f state) pass.structure_item;
               signature_item =
                 Option.map (fun f -> f state) pass.signature_item;
               finish = (fun () -> pass.finish ctx state);
             })
    | File _ | Pass _ | Project _ | Project_units _ -> None

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
    | File _ | Pass _ -> []

  let project_job (Job { code; title; pp; run }) =
    List.map (fun issue -> Result (code, title, pp, issue)) (run ())

  let pass_expr (Active_pass { expr; _ }) = expr
  let pass_value_binding (Active_pass { value_binding; _ }) = value_binding
  let pass_structure_item (Active_pass { structure_item; _ }) = structure_item
  let pass_signature_item (Active_pass { signature_item; _ }) = signature_item

  let pass_finish (Active_pass { code; title; pp; finish; _ }) =
    List.map (fun issue -> Result (code, title, pp, issue)) (finish ())

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
