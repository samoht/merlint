(** E325: Function Naming Convention *)

type payload = { function_name : string; expected : string }
(** Payload for bad function naming *)

(** Convert Outline.kind to string *)
let kind_to_string = function
  | Outline.Value -> "Value"
  | Outline.Type -> "Type"
  | Outline.Module -> "Module"
  | Outline.Class -> "Class"
  | Outline.Exception -> "Exception"
  | Outline.Constructor -> "Constructor"
  | Outline.Field -> "Field"
  | Outline.Method -> "Method"
  | Outline.Other s -> s

(** Check if a return type is an option type *)
let returns_option return_type =
  String.ends_with ~suffix:"option" (String.trim return_type)

(* Check a single function for naming issues *)
let check_single_function filename name kind type_sig location =
  ignore filename;
  match (name, kind, type_sig, location) with
  | Some n, Some "Value", Some ts, Some loc when Outline.is_function_type ts ->
      let return_type = Outline.extract_return_type ts in
      let is_option = returns_option return_type in
      (* Check get_* functions or just 'get' *)
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
        (String.starts_with ~prefix:"find_" n || n = "find") && not is_option
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
      else None
  | _ -> None

let check ctx =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  List.filter_map
    (fun item ->
      let location = Outline.location filename item in
      check_single_function filename (Some item.name)
        (Some (kind_to_string item.kind))
        item.type_sig location)
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
