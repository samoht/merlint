(** E200: Outdated Str Module *)

let check ctx =
  let ast_data = Context.ast ctx in

  (* Check identifiers for Str module usage *)
  Traverse.check_module_usage ast_data.identifiers "Str" (fun ~loc ->
      Issue.use_str_module ~loc)
