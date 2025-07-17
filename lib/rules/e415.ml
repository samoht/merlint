(** E415: Missing Standard Functions *)

type payload = { reason : string }

let check (_ctx : Context.file) =
  (* TODO: E415 - Implement missing standard functions check
     This rule should check that types implement standard functions like equal, compare, etc.
     Currently not implemented. *)
  [
    Issue.v { reason = "Missing standard functions check not yet implemented" };
  ]

let pp ppf { reason } = Fmt.pf ppf "%s" reason

let rule =
  Rule.v ~code:"E415" ~title:"Missing Standard Functions"
    ~category:Documentation
    ~hint:
      "Types should implement standard functions like equal, compare, pp \
       (pretty-printer), and to_string for better usability and consistency \
       across the codebase."
    ~examples:[] ~pp (File check)
