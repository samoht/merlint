(** E410: Bad Documentation Style *)

type payload = { reason : string }

let check (_ctx : Context.file) =
  (* TODO: E410 - Implement bad documentation style check
     This rule should check documentation style and formatting.
     Currently not implemented. *)
  [ Issue.v { reason = "Bad documentation style check not yet implemented" } ]

let pp ppf { reason } = Fmt.pf ppf "%s" reason

let rule =
  Rule.v ~code:"E410" ~title:"Bad Documentation Style" ~category:Documentation
    ~hint:
      "Documentation should follow OCaml conventions: start with a capital \
       letter, end with a period, and use proper grammar. Avoid redundant \
       phrases like 'This function...' - just state what it does directly."
    ~examples:[] ~pp (File check)
