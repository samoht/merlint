(** E305: Module Naming Convention *)

(** Convert PascalCase to Snake_case *)
let to_snake_case name =
  let result = Buffer.create (String.length name * 2) in
  String.iteri
    (fun i ch ->
      if i > 0 && Char.uppercase_ascii ch = ch && Char.lowercase_ascii ch <> ch
      then (
        (* Add underscore before uppercase letter if previous char was lowercase *)
        if i > 0 && Char.lowercase_ascii name.[i - 1] = name.[i - 1] then
          Buffer.add_char result '_';
        Buffer.add_char result (Char.lowercase_ascii ch))
      else Buffer.add_char result ch)
    name;
  let s = Buffer.contents result in
  (* Capitalize first letter *)
  if String.length s > 0 then String.capitalize_ascii s else s

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
  List.filter_map
    (fun (module_elt : Ast.elt) ->
      let module_name = Ast.name_to_string module_elt.name in
      if not (is_snake_case_module module_name) then
        let expected = to_snake_case module_name in
        let location =
          match module_elt.location with
          | Some loc -> loc
          | None ->
              Location.create ~file:"unknown" ~start_line:1 ~start_col:1
                ~end_line:1 ~end_col:1
        in
        Some (Issue.Bad_module_naming { module_name; location; expected })
      else None)
    (Context.ast ctx).modules
