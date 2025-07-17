(** E510: Missing Log Source *)

type payload = { reason : string }
(** Payload for disabled rules *)

let check (_ctx : Context.file) =
  (* TODO: E510 - Implement missing log source check
     This rule should check that logging calls include a source parameter.
     Currently not implemented. *)
  [ Issue.v { reason = "Missing log source check not yet implemented" } ]

let pp ppf { reason } = Fmt.pf ppf "%s" reason

let rule =
  Rule.v ~code:"E510" ~title:"Missing Log Source" ~category:Project_structure
    ~hint:
      "Modules that use logging should declare a log source for better \
       debugging and log filtering. Add 'let src = Logs.Src.create \
       \"module.name\" ~doc:\"...\"'"
    ~examples:[] ~pp (File check)
