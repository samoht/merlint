(** E330: Redundant Module Name *)

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

(** Check if an item name has redundant module prefix *)
let has_redundant_prefix item_name_lower module_name =
  String.starts_with ~prefix:(module_name ^ "_") item_name_lower
  || item_name_lower = module_name

(** Create redundant module name issue *)
let create_redundant_name_issue item_name module_name location item_type =
  Issue.redundant_module_name ~item_name
    ~module_name:(String.capitalize_ascii module_name)
    ~loc:location ~item_type

(* Helper to check if a type signature is a function type *)
let is_function_type type_sig = String.contains type_sig '-'

let check (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  let module_name =
    Filename.basename filename |> Filename.remove_extension
    |> String.lowercase_ascii
  in
  List.filter_map
    (fun (item : Outline.item) ->
      let name = item.name in
      let location = Traverse.extract_outline_location filename item in
      let item_name_lower = String.lowercase_ascii name in
      if has_redundant_prefix item_name_lower module_name then
        match (kind_to_string item.kind, item.type_sig, location) with
        | "Value", Some ts, Some loc when is_function_type ts ->
            Some (create_redundant_name_issue name module_name loc "function")
        | "Value", Some _, Some loc ->
            Some (create_redundant_name_issue name module_name loc "value")
        | "Type", _, Some loc ->
            Some (create_redundant_name_issue name module_name loc "type")
        | _ -> None
      else None)
    outline_data
