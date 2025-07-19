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
    ~examples:
      [
        {
          is_good = true;
          code =
            {|let log_src = Logs.Src.create "project_name.module_name"
module Log = (val Logs.src_log log_src : Logs.LOG)|};
        };
        {
          is_good = true;
          code =
            {|Log.info (fun m ->
    m "Received event: %s" event_type
      ~tags:(Logs.Tag.add "channel_id" channel_id Logs.Tag.empty))|};
        };
      ]
    ~pp (File check)
