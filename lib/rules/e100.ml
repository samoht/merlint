(** E100: No Obj.magic *)

let check (ctx : Context.file) =
  let ast_data = Context.ast ctx in

  (* Check identifiers for Obj.magic usage *)
  Traverse.check_function_usage ast_data.identifiers "Obj" "magic" (fun ~loc ->
      Issue.no_obj_magic ~loc)
