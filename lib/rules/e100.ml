(** E100: No Obj.magic *)

let check typedtree =
  let issues = ref [] in

  (* Check identifiers for Obj.magic usage *)
  List.iter
    (fun (id : Ast.elt) ->
      match id.location with
      | Some loc -> (
          let name = id.name in
          let prefix = name.prefix in
          let base = name.base in

          (* Pattern match on the module path and base identifier *)
          match (prefix, base) with
          | ([ "Obj" ] | [ "Stdlib"; "Obj" ]), "magic" ->
              issues := Issue.No_obj_magic { location = loc } :: !issues
          | _ -> ())
      | None -> ())
    typedtree.Typedtree.identifiers;

  !issues
