(** E415: Missing Exception Documentation *)

let check (_ctx : Context.file) =
  (* TODO: E415 - Implement missing exception documentation check
     This rule should check that public exceptions have documentation.
     Currently not implemented. *)
  raise
    (Issue.Disabled
       "E415: Missing exception documentation check not yet implemented")
