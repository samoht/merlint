(** Linting engine *)

let src = Logs.Src.create "merlint.engine" ~doc:"Linting engine"

module Log = (val Logs.src_log src : Logs.LOG)

(** Find the project root by looking for dune-project file *)
let project_root path =
  let rec find_root current =
    let dune_project = Filename.concat current "dune-project" in
    if Sys.file_exists dune_project then current
    else
      let parent = Filename.dirname current in
      if parent = current then
        (* We've reached the root of the filesystem *)
        Sys.getcwd ()
      else find_root parent
  in
  if Sys.file_exists path && Sys.is_directory path then find_root path
  else if Sys.file_exists path then find_root (Filename.dirname path)
  else Sys.getcwd ()

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

(** Run all checks on a project *)
let run ~filter ~dune_describe ?profiling project_root =
  Log.info (fun m -> m "Starting analysis of %s" project_root);

  (* Load configuration *)
  let config = Config.load_from_path project_root in

  (* Get all project files from dune describe *)
  let files_to_analyze = Dune.project_files dune_describe in
  let files_to_analyze_str = List.map Fpath.to_string files_to_analyze in

  (* Create project context *)
  let project_ctx =
    Context.project ~config ~project_root ~all_files:files_to_analyze_str
      ~dune_describe
  in

  (* Get all rules and filter them *)
  let all_rules = Data.all_rules in
  let enabled_rules =
    List.filter
      (fun rule -> Filter.is_enabled_by_code filter (Rule.code rule))
      all_rules
  in

  (* Run project-scoped rules *)
  let project_issues =
    enabled_rules
    |> List.filter Rule.is_project_scoped
    |> List.concat_map (run_project_rule ?profiling project_ctx)
  in

  (* Run file-scoped rules on each file *)
  let file_rules = List.filter Rule.is_file_scoped enabled_rules in
  let file_issues =
    List.concat_map
      (fun filepath ->
        let filename = Fpath.to_string filepath in
        try
          (* Run Merlin on the file *)
          let merlin_start = Unix.gettimeofday () in
          let merlin_result = Merlin.analyze_file filename in
          let merlin_duration = Unix.gettimeofday () -. merlin_start in
          (match profiling with
          | Some prof ->
              Profiling.add_timing prof
                {
                  operation = Profiling.Merlin filename;
                  duration = merlin_duration;
                }
          | None -> ());
          let file_ctx =
            Context.file ~filename ~config ~project_root ~merlin_result
          in
          (* Filter rules based on exclusions for this file *)
          let applicable_rules =
            List.filter
              (fun rule ->
                not
                  (Exclusions.should_exclude config.exclusions
                     ~rule:(Rule.code rule) ~file:filename))
              file_rules
          in
          List.concat_map (run_file_rule ?profiling file_ctx) applicable_rules
        with exn ->
          Log.err (fun m ->
              m "Failed to analyze %s: %s" filename (Printexc.to_string exn));
          [])
      files_to_analyze
  in

  (* Combine all issues *)
  let all_issues = project_issues @ file_issues in

  (* Sort issues by location *)
  List.sort Rule.Run.compare all_issues
