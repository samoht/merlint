(** E510: Missing Log Source *)

let check (_ctx : Context.file) =
  (* TODO: E510 - Implement missing log source check
     This rule should check that logging calls include a source parameter.
     Currently not implemented. *)
  raise (Issue.Disabled "E510: Missing log source check not yet implemented")
