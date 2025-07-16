(** E405: Missing Type Documentation *)

let check (_ctx : Context.t) =
  (* TODO: E405 - Implement missing type documentation check
     This rule should check that public types have documentation.
     Currently not implemented. *)
  raise
    (Issue.Disabled "E405: Missing type documentation check not yet implemented")
