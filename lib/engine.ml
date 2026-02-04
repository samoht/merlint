(** Linting engine *)

let src = Logs.Src.create "merlint.engine" ~doc:"Linting engine"

module Log = (val Logs.src_log src : Logs.LOG)

(** Run a single rule on a file *)
let run_file_rule ?profiling ctx rule =
  let code = Rule.code rule in
  Log.debug (fun m -> m "Running rule %s on %s" code ctx.Context.filename);
  let start_time = Unix.gettimeofday () in
  let result =
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
  result

(** Run a single rule on a project *)
let run_project_rule ?profiling ctx rule =
  let code = Rule.code rule in
  Log.debug (fun m -> m "Running project rule %s" code);
  let start_time = Unix.gettimeofday () in
  let result =
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
  result

(** Setup analysis context and enabled rules *)
let setup_analysis ~filter ~dune_describe project_root =
  let config = Config.load_from_path project_root in
  let files_to_analyze = Dune.project_files dune_describe in
  let files_to_analyze_str = List.map Fpath.to_string files_to_analyze in
  let project_ctx =
    Context.project ~config ~project_root ~all_files:files_to_analyze_str
      ~dune_describe
  in
  let enabled_rules =
    Data.all_rules
    |> List.filter (fun rule ->
           Filter.is_enabled_by_code filter (Rule.code rule))
  in
  (config, files_to_analyze, project_ctx, enabled_rules)

(** Run project-scoped rules and filter issues based on exclusions *)
let run_project_rules ?profiling enabled_rules project_ctx =
  let config = project_ctx.Context.config in
  enabled_rules
  |> List.filter Rule.is_project_scoped
  |> List.concat_map (fun rule ->
         let code = Rule.code rule in
         let issues = run_project_rule ?profiling project_ctx rule in
         (* Filter out issues for files that are excluded from this rule *)
         List.filter
           (fun result ->
             match Rule.Run.location result with
             | Some loc ->
                 let file = loc.Location.file in
                 let excluded =
                   Rule_config.should_exclude config.exclusions ~rule:code ~file
                 in
                 if excluded then
                   Log.debug (fun m ->
                       m "Excluding %s issue for file %s" code file);
                 not excluded
             | None ->
                 (* Issues without locations can't be excluded by file *)
                 true)
           issues)

(** Analyze a single file with applicable rules *)
let analyze_single_file ?profiling ~config ~project_root ~file_rules filepath =
  let filename = Fpath.to_string filepath in
  try
    let merlin_start = Unix.gettimeofday () in
    let merlin_result = Merlin.analyze_file filename in
    let merlin_duration = Unix.gettimeofday () -. merlin_start in
    (match profiling with
    | Some prof ->
        Profiling.add_timing prof
          { operation = Profiling.Merlin filename; duration = merlin_duration }
    | None -> ());
    let file_ctx =
      Context.file ~filename ~config ~project_root ~merlin_result
    in
    let applicable_rules =
      List.filter
        (fun rule ->
          let code = Rule.code rule in
          let excluded =
            Rule_config.should_exclude config.exclusions ~rule:code
              ~file:filename
          in
          if excluded then
            Log.debug (fun m -> m "Excluding rule %s for file %s" code filename);
          not excluded)
        file_rules
    in
    List.concat_map (run_file_rule ?profiling file_ctx) applicable_rules
  with exn ->
    Log.err (fun m ->
        m "Failed to analyze %s: %s" filename (Printexc.to_string exn));
    []

(** Run all checks on a project *)
let run ~filter ~dune_describe ?profiling project_root =
  Log.info (fun m -> m "Starting analysis of %s" project_root);

  let config, files_to_analyze, project_ctx, enabled_rules =
    setup_analysis ~filter ~dune_describe project_root
  in

  let project_issues = run_project_rules ?profiling enabled_rules project_ctx in

  let file_rules = List.filter Rule.is_file_scoped enabled_rules in
  let file_issues =
    List.concat_map
      (analyze_single_file ?profiling ~config ~project_root ~file_rules)
      files_to_analyze
  in

  let all_issues = project_issues @ file_issues in
  List.sort Rule.Run.compare all_issues
