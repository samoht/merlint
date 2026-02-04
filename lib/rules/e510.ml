(** E510: Missing Log Source *)

type payload = { module_name : string }

let check (ctx : Context.file) =
  try
    let dump_data = Context.dump ctx in
    (* Get all identifiers from the typedtree *)
    let identifiers = dump_data.Dump.identifiers in

    (* Check if any logging functions are used *)
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
    in

    let uses_logging =
      List.exists
        (fun (module_name, func_name) ->
          List.exists
            (fun ident ->
              match ident.Dump.name.prefix with
              | prefix_mod :: _ when prefix_mod = module_name ->
                  ident.name.base = func_name
              | _ -> false)
            identifiers)
        log_functions
    in

    (* Check if log source is defined *)
    let has_log_source =
      List.exists
        (fun ident ->
          match (ident.Dump.name.prefix, ident.name.base) with
          | [ "Logs"; "Src" ], "create" -> true
          | [ "Logs" ], "src_log" -> true
          | _, ("log_src" | "src") ->
              (* Check if it's a value definition for log source *)
              List.exists
                (fun value -> value.Dump.name.base = ident.name.base)
                dump_data.values
          | _ -> false)
        identifiers
    in

    if uses_logging && not has_log_source then
      let module_name =
        Filename.basename ctx.filename
        |> Filename.remove_extension |> String.capitalize_ascii
      in
      [ Issue.v { module_name } ]
    else []
  with _ ->
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
