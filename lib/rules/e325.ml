(** E325: Function Naming Convention *)

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

(** Check if a type signature represents a function *)
let is_function_type type_sig = String.contains type_sig '>'

(** Get the return type from a function signature *)
let get_return_type type_sig =
  (* Find the last '->' in the signature *)
  try
    let rec find_last_arrow i =
      match String.index_from_opt type_sig i '>' with
      | None -> -1
      | Some idx ->
          if idx > 0 && type_sig.[idx - 1] = '-' then
            match String.index_from_opt type_sig (idx + 1) '>' with
            | None -> idx
            | Some _ -> find_last_arrow (idx + 1)
          else find_last_arrow (idx + 1)
    in
    let last_arrow = find_last_arrow 0 in
    if last_arrow > 0 then
      String.trim
        (String.sub type_sig (last_arrow + 1)
           (String.length type_sig - last_arrow - 1))
    else type_sig
  with _ -> type_sig

(** Check if a return type is an option type *)
let returns_option return_type =
  String.ends_with ~suffix:"option" (String.trim return_type)

let extract_outline_location filename (item : Outline.item) =
  match item.range with
  | Some range ->
      Some
        (Location.create ~file:filename ~start_line:range.start.line
           ~start_col:range.start.col ~end_line:range.start.line
           ~end_col:range.start.col)
  | None -> None

(* Check a single function for naming issues *)
let check_single_function _filename name kind type_sig location =
  match (name, kind, type_sig, location) with
  | Some n, Some "Value", Some ts, Some loc when is_function_type ts ->
      let return_type = get_return_type ts in
      let is_option = returns_option return_type in
      (* Check get_* functions or just 'get' *)
      if (String.starts_with ~prefix:"get_" n || n = "get") && is_option then
        Some
          (Issue.Bad_function_naming
             {
               function_name = n;
               location = loc;
               suggestion =
                 (if n = "get" then "find"
                  else
                    let suffix = String.sub n 4 (String.length n - 4) in
                    "find_" ^ suffix);
             }) (* Check find_* functions or just 'find' *)
      else if
        (String.starts_with ~prefix:"find_" n || n = "find") && not is_option
      then
        Some
          (Issue.Bad_function_naming
             {
               function_name = n;
               location = loc;
               suggestion =
                 (if n = "find" then "get"
                  else
                    let suffix = String.sub n 5 (String.length n - 5) in
                    "get_" ^ suffix);
             })
      else None
  | _ -> None

let check (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  List.filter_map
    (fun item ->
      let location = extract_outline_location filename item in
      check_single_function filename (Some item.name)
        (Some (kind_to_string item.kind))
        item.type_sig location)
    outline_data
