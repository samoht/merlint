(** E310: Value Naming Convention *)

let check_value_name name =
  let expected = Traverse.to_snake_case name in
  if name <> expected && name <> String.lowercase_ascii name then Some expected
  else None

let check ctx =
  (* Check value names *)
  Traverse.check_elements (Context.ast ctx).patterns check_value_name
    (fun name_str loc expected ->
      Issue.bad_value_naming ~value_name:name_str ~loc ~expected)
