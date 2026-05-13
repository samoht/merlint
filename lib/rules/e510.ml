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

let uses_logging identifiers =
  List.exists
    (fun (module_name, func_name) ->
      List.exists
        (fun (ident : Merlin.Dump.elt) ->
          match ident.name.prefix with
          | prefix_mod :: _ when prefix_mod = module_name ->
              ident.name.base = func_name
          | _ -> false)
        identifiers)
    log_functions

let has_log_source dump_data identifiers =
  List.exists
    (fun (ident : Merlin.Dump.elt) ->
      match (ident.name.prefix, ident.name.base) with
      | [ "Logs"; "Src" ], "create" -> true
      | [ "Logs" ], "src_log" -> true
      | _, ("log_src" | "src") ->
          List.exists
            (fun (value : Merlin.Dump.elt) -> value.name.base = ident.name.base)
            dump_data.Merlin.Dump.values
      | _ -> false)
    identifiers

let check (ctx : Context.file) =
  try
    let dump_data = Context.dump ctx in
    let identifiers = dump_data.Merlin.Dump.identifiers in
    if uses_logging identifiers && not (has_log_source dump_data identifiers)
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
  with Context.Analysis_error _ ->
    (* If we can't parse the dump, skip this check *)
    []

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
