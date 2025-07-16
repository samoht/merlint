(** E305: Module Naming Convention *)

(** Check if module name follows Snake_case convention *)
let is_snake_case_module name =
  (* Must start with uppercase *)
  String.length name > 0
  && Char.uppercase_ascii name.[0] = name.[0]
  &&
  (* Rest should be lowercase or underscores *)
  String.for_all
    (fun ch -> Char.lowercase_ascii ch = ch || ch = '_')
    (String.sub name 1 (String.length name - 1))

let check ctx =
  let ast_data = Context.ast ctx in

  (* Check modules for naming convention *)
  List.filter_map
    (fun (module_elt : Ast.elt) ->
      let module_name = Ast.name_to_string module_elt.name in
      if not (is_snake_case_module module_name) then
        let expected = Traverse.to_snake_case module_name in
        match Traverse.extract_location module_elt with
        | Some loc -> Some (Issue.bad_module_naming ~module_name ~loc ~expected)
        | None -> None
      else None)
    ast_data.modules
