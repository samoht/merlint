(** E510: Missing Log Source *)

type payload = { module_name : string }

let log_functions =
  [
    ("Logs", "debug");
    ("Logs", "info");
    ("Logs", "warn");
    ("Logs", "err");
    ("Logs", "app");
    ("Log", "debug");
    ("Log", "info");
    ("Log", "warn");
    ("Log", "err");
    ("Log", "app");
  ]

module Ref = File_view.Reference

let uses_logging identifiers =
  List.exists
    (fun (module_name, func_name) ->
      List.exists
        (fun ident ->
          match Ref.prefix ident with
          | prefix_mod :: _ when prefix_mod = module_name ->
              Ref.base ident = func_name
          | _ -> false)
        identifiers)
    log_functions

let has_log_source values identifiers =
  List.exists
    (fun ident ->
      match (Ref.prefix ident, Ref.base ident) with
      | [ "Logs"; "Src" ], "create" -> true
      | [ "Logs" ], "src_log" -> true
      | _, ("log_src" | "src") ->
          let base = Ref.base ident in
          List.exists (fun value -> Ref.base value = base) values
      | _ -> false)
    identifiers

(* Looks for resolved [Logs.X] / [Log.X] calls and a corresponding log
   source declaration. Requires typedtree so a user's local [Logs]
   module doesn't trip the rule; the engine surfaces the missing-
   resolution count. *)
let check (ctx : Context.file) =
  try
    let view = Context.view ctx in
    match
      (File_view.resolved_identifiers view, File_view.resolved_values view)
    with
    | None, _ | _, None -> []
    | Some identifiers, Some values ->
        if uses_logging identifiers && not (has_log_source values identifiers)
        then
          let module_name =
            Filename.basename ctx.filename
            |> Filename.remove_extension |> String.capitalize_ascii
          in
          let loc =
            let pos = { Location.line = 1; col = 0 } in
            { Location.file = ctx.filename; start = pos; end_ = pos }
          in
          [ Issue.v ~loc { module_name } ]
        else []
  with File_view.Analysis_error _ -> []

let pp ppf { module_name } =
  Fmt.pf ppf "Module '%s' uses logging but has no log source defined"
    module_name

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
