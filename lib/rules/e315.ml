(** E315: Type Naming Convention *)

let check ctx =
  (* Check type names *)
  Traverse.check_elements (Context.ast ctx).types
    (fun name_str ->
      if
        name_str <> "t" && name_str <> "id"
        && name_str <> Traverse.to_snake_case name_str
      then Some "should use snake_case"
      else None)
    (fun name_str loc message ->
      Issue.bad_type_naming ~type_name:name_str ~loc ~message)
