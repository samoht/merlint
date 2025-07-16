(** E410: Missing Value Documentation *)

let check (_ctx : Context.file) =
  (* TODO: E410 - Implement missing value documentation check
     This rule should check that public values have documentation.
     Currently not implemented. *)
  raise
    (Issue.Disabled
       "E410: Missing value documentation check not yet implemented")
