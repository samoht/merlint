(** E325: Function Naming Convention *)

type payload = { function_name : string; expected : string }

(** Stdlib-aligned [find_*] names whose return shape is a collection (not an
    option): [List.find_all], [Hashtbl.find_all], etc. *)
let is_stdlib_find_collection_name name =
  name = "find_all" || name = "find_many"

(** A type-variable [Ptyp_var "a"] means merlin couldn't resolve the type; skip
    the rule rather than guess. *)
let is_unresolved_type ct =
  match ct.Parsetree.ptyp_desc with Ptyp_var _ | Ptyp_any -> true | _ -> false

let check_single_function (item : Outline.item) loc =
  if item.kind <> Outline.Value then None
  else if not (Outline.is_function_type item) then None
  else
    let n = item.name in
    match Outline.return_type item with
    | None -> None
    | Some ret when is_unresolved_type ret -> None
    | Some ret ->
        let is_option = Outline.returns_option item in
        if (String.starts_with ~prefix:"get_" n || n = "get") && is_option then
          Some
            (Issue.v ~loc
               {
                 function_name = n;
                 expected =
                   (if n = "get" then "find"
                    else
                      let suffix = String.sub n 4 (String.length n - 4) in
                      "find_" ^ suffix);
               })
        else if
          (String.starts_with ~prefix:"find_" n || n = "find")
          && (not is_option)
          && not (is_stdlib_find_collection_name n)
        then
          Some
            (Issue.v ~loc
               {
                 function_name = n;
                 expected =
                   (if n = "find" then "get"
                    else
                      let suffix = String.sub n 5 (String.length n - 5) in
                      "get_" ^ suffix);
               })
        else
          let _ = ret in
          None

let check ctx =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  List.filter_map
    (fun (item : Outline.item) ->
      match Outline.location filename item with
      | Some loc -> check_single_function item loc
      | None -> None)
    outline_data

let pp ppf { function_name; expected } =
  Fmt.pf ppf "Function '%s' naming convention: consider '%s'" function_name
    expected

let rule =
  Rule.v ~code:"E325" ~title:"Function Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Functions that return option types should be prefixed with 'find_', \
       while functions that return non-option types should be prefixed with \
       'get_'. This convention helps communicate the function's behavior to \
       callers."
    ~examples:
      [ Example.bad Examples.E325.bad_ml; Example.good Examples.E325.good_ml ]
    ~pp (File check)
