(** Linting engine *)

let src = Logs.Src.create "merlint.engine" ~doc:"Linting engine"

module Log = (val Logs.src_log src : Logs.LOG)

type exclusion_stats = { rule : string; file : string }
type result = { issues : Rule.Run.result list; excluded : exclusion_stats list }

let run_file_rule ?profiling ctx rule =
  let code = Rule.code rule in
  Log.debug (fun m -> m "Running rule %s on %s" code ctx.Context.filename);
  let start_time = Unix.gettimeofday () in
  let res =
    try Rule.Run.file rule ctx
    with exn ->
      Log.err (fun m ->
          m "Rule %s failed on %s: %s" code ctx.Context.filename
            (Printexc.to_string exn));
      []
  in
  let duration = Unix.gettimeofday () -. start_time in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        {
          operation =
            Profiling.File_rule
              { rule_code = code; filename = ctx.Context.filename };
          duration;
        }
  | None -> ());
  res

let run_project_rule ?profiling ctx rule =
  let code = Rule.code rule in
  Log.debug (fun m -> m "Running project rule %s" code);
  let start_time = Unix.gettimeofday () in
  let res =
    try Rule.Run.project rule ctx
    with exn ->
      Log.err (fun m ->
          m "Project rule %s failed: %s" code (Printexc.to_string exn));
      []
  in
  let duration = Unix.gettimeofday () -. start_time in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        { operation = Profiling.Project_rule code; duration }
  | None -> ());
  res

let setup_analysis ~filter ~dune_describe ~files_to_analyze ~index project_root
    =
  let config = Config.load project_root in
  let files_to_analyze_str = List.map Fpath.to_string files_to_analyze in
  let project_ctx =
    Context.project ~config ~project_root ~all_files:files_to_analyze_str
      ~dune_describe ~index
  in
  let enabled_rules =
    Data.all_rules
    |> List.filter (fun rule ->
        Filter.is_enabled_by_code filter (Rule.code rule))
  in
  (config, project_ctx, enabled_rules)

let config_lookup () =
  let cache = Hashtbl.create 32 in
  fun file ->
    let dir = if Sys.file_exists file then Filename.dirname file else file in
    match Hashtbl.find_opt cache dir with
    | Some c -> c
    | None ->
        let c = Config.for_file file in
        Hashtbl.add cache dir c;
        c

let is_result_excluded ~config_for ~code ~excluded_acc r =
  match Rule.Run.location r with
  | None -> false
  | Some loc ->
      let file = loc.Location.file in
      let cfg : Config.t = config_for file in
      let skip = Rule_config.should_exclude cfg.exclusions ~rule:code ~file in
      if skip then excluded_acc := { rule = code; file } :: !excluded_acc;
      skip

let run_one_project_rule ?profiling ~config_for ~excluded_acc project_ctx rule =
  let code = Rule.code rule in
  let issues = run_project_rule ?profiling project_ctx rule in
  List.filter
    (fun r -> not (is_result_excluded ~config_for ~code ~excluded_acc r))
    issues

let run_project_rules ?profiling enabled_rules project_ctx =
  let config_for = config_lookup () in
  let excluded_acc = ref [] in
  let issues =
    enabled_rules
    |> List.filter Rule.is_project_scoped
    |> List.concat_map
         (run_one_project_rule ?profiling ~config_for ~excluded_acc project_ctx)
  in
  (issues, List.rev !excluded_acc)

let analyze_single_file ?profiling ~backend ~config_for ~project_root
    ~file_rules filepath =
  let filename = Fpath.to_string filepath in
  let config = config_for filename in
  let excluded_acc = ref [] in
  let issues =
    try
      (* Both Merlin calls are slow (each parses+typechecks the file via
         merlin-kernel). Defer them: rules that don't ask for outline or
         dump pay nothing, and a profiling record is only emitted when the
         thunk actually runs. *)
      let merlin_op f =
        let start = Unix.gettimeofday () in
        let r = f () in
        let duration = Unix.gettimeofday () -. start in
        (match profiling with
        | Some prof ->
            Profiling.add_timing prof
              { operation = Profiling.Merlin filename; duration }
        | None -> ());
        r
      in
      let outline () =
        merlin_op (fun () -> Merlin.outline backend ~file:filename)
      in
      let dump () =
        merlin_op (fun () -> Merlin.dump_ast backend ~file:filename)
      in
      let file_ctx =
        Context.file ~filename ~config ~project_root ~outline ~dump
      in
      let all_results =
        List.concat_map (run_file_rule ?profiling file_ctx) file_rules
      in
      List.filter
        (fun r ->
          let code = Rule.Run.code r in
          let skip =
            Rule_config.should_exclude config.exclusions ~rule:code
              ~file:filename
          in
          if skip then
            excluded_acc := { rule = code; file = filename } :: !excluded_acc;
          not skip)
        all_results
    with exn ->
      Log.err (fun m ->
          m "Failed to analyze %s: %s" filename (Printexc.to_string exn));
      []
  in
  (issues, List.rev !excluded_acc)

let run ~filter ~dune_describe ?files_to_analyze ~index ?profiling project_root
    =
  Log.info (fun m -> m "Starting analysis of %s" project_root);
  let files_to_analyze =
    match files_to_analyze with
    | Some files -> files
    | None -> Dune_describe.project_files dune_describe
  in
  let _config, project_ctx, enabled_rules =
    setup_analysis ~filter ~dune_describe ~files_to_analyze ~index project_root
  in
  let project_issues, project_excluded =
    run_project_rules ?profiling enabled_rules project_ctx
  in
  let file_rules = List.filter Rule.is_file_scoped enabled_rules in
  let backend = Merlin.v () in
  let config_for = config_lookup () in
  let analyze_file =
    analyze_single_file ?profiling ~backend ~config_for ~project_root
      ~file_rules
  in
  let file_results = List.map analyze_file files_to_analyze in
  Merlin.close backend;
  let file_issues = List.concat_map fst file_results in
  let file_excluded = List.concat_map snd file_results in
  {
    issues = List.sort Rule.Run.compare (project_issues @ file_issues);
    excluded = project_excluded @ file_excluded;
  }
