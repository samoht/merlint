(** Centralized rules coordinator for all merlint checks *)

exception Disabled of string

type config = { merlint_config : Config.t; project_root : string }

let get_project_root file =
  (* Walk up directories to find project root (contains dune-project) *)
  let rec find_root dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then dir (* reached filesystem root *)
      else find_root parent
  in
  let file_dir =
    if Sys.is_directory file then file else Filename.dirname file
  in
  find_root file_dir

let default_config project_root =
  { merlint_config = Config.default; project_root }

let filter_issues rule_filter issues =
  match rule_filter with
  | None -> issues
  | Some filter -> Rule_filter.filter_issues filter issues

let run_format_rules config files rule_filter =
  let e500_issues = E500.check config.project_root in
  let e505_issues = E505.check config.project_root files in
  let issues = e500_issues @ e505_issues in
  let filtered_issues = filter_issues rule_filter issues in
  Report.create ~rule_name:"Format rules (.ocamlformat, .mli files)"
    ~passed:(filtered_issues = []) ~issues:filtered_issues ~file_count:1

let run_documentation_rules _config files rule_filter =
  let e400_issues = E400.check files in
  let filtered_issues = filter_issues rule_filter e400_issues in
  let mli_files = List.filter (String.ends_with ~suffix:".mli") files in

  Report.create ~rule_name:"Documentation rules (module docs)"
    ~passed:(filtered_issues = []) ~issues:filtered_issues
    ~file_count:(List.length mli_files)

let run_test_convention_rules _config files rule_filter =
  let e600_issues = E600.check files in
  let filtered_issues = filter_issues rule_filter e600_issues in
  let test_files =
    List.filter
      (fun f ->
        String.ends_with ~suffix:"_test.ml" f || Filename.basename f = "test.ml")
      files
  in

  Report.create ~rule_name:"Test conventions (export 'suite' not module name)"
    ~passed:(filtered_issues = []) ~issues:filtered_issues
    ~file_count:(List.length test_files)

let run_warning_rules _config files rule_filter =
  let e110_issues = E110.check files in
  let filtered_issues = filter_issues rule_filter e110_issues in

  Report.create ~rule_name:"Warning rules (no silenced warnings)"
    ~passed:(filtered_issues = []) ~issues:filtered_issues
    ~file_count:(List.length files)

let run_test_coverage_rules dune_describe files rule_filter =
  let e605_issues =
    try E605.check dune_describe files with Issue.Disabled _ -> []
  in
  let e610_issues =
    try E610.check dune_describe files with Issue.Disabled _ -> []
  in
  let e615_issues =
    try E615.check dune_describe files with Issue.Disabled _ -> []
  in
  let all_issues = e605_issues @ e610_issues @ e615_issues in
  let filtered_issues = filter_issues rule_filter all_issues in

  Report.create ~rule_name:"Test coverage (1:1 lib/test correspondence)"
    ~passed:(filtered_issues = []) ~issues:filtered_issues
    ~file_count:(List.length files)

(* Process a single file analysis *)
let process_file_analysis config (file, analysis) =
  let complexity_issues =
    match analysis.Merlin.browse with
    | Ok browse_result ->
        let e001_config =
          { E001.max_complexity = config.merlint_config.max_complexity }
        in
        let e010_config =
          { E010.max_nesting = config.merlint_config.max_nesting }
        in
        let e001_issues = E001.check e001_config browse_result in
        let e010_issues = E010.check e010_config browse_result in
        (* Also keep the original complexity checks for function length *)
        let e005_config =
          {
            E005.max_function_length = config.merlint_config.max_function_length;
          }
        in
        let e005_issues = E005.check e005_config browse_result in
        e001_issues @ e010_issues @ e005_issues
    | Error _ -> []
  in

  let style_issues, naming_issues =
    match analysis.Merlin.typedtree with
    | Ok typedtree_result ->
        let e100_issues = E100.check typedtree_result in
        let e200_issues = E200.check typedtree_result in
        let e205_issues = E205.check typedtree_result in
        let outline =
          match analysis.Merlin.outline with Ok o -> Some o | Error _ -> None
        in
        let e310_issues =
          try E310.check ~filename:file ~outline typedtree_result
          with Issue.Disabled _ -> []
        in
        let e315_issues = E315.check typedtree_result in
        let e320_issues = E320.check typedtree_result in
        let e325_issues = E325.check ~filename:file ~outline in
        let e330_issues = E330.check ~filename:file ~outline in
        let e335_issues = E335.check typedtree_result in
        let e300_issues = E300.check typedtree_result in
        let e305_issues = E305.check typedtree_result in
        let e350_issues = E350.check ~filename:file ~outline typedtree_result in
        let e351_issues =
          match outline with
          | Some outline_data ->
              E351.check_global_mutable_state ~filename:file outline_data
          | None -> []
        in
        ( e100_issues @ e200_issues @ e205_issues @ e351_issues,
          e310_issues @ e315_issues @ e320_issues @ e325_issues @ e330_issues
          @ e335_issues @ e300_issues @ e305_issues @ e350_issues )
    | Error _ -> ([], [])
  in

  (* E105 is now a text-based check - moved to pattern_issues section *)
  let e105_issues = [] in

  (* Run text-based pattern detection *)
  let pattern_issues =
    if String.ends_with ~suffix:".ml" file then
      try
        let content = In_channel.with_open_text file In_channel.input_all in
        let e340_text_issues = E340.check file content in
        let e105_text_issues = E105.check file content in
        e340_text_issues @ e105_text_issues
      with _ -> []
    else []
  in

  (complexity_issues, style_issues @ e105_issues @ pattern_issues, naming_issues)

(* Aggregate issues from all file analyses *)
let aggregate_issues config file_analyses =
  List.fold_left
    (fun (comp, style, naming) file_analysis ->
      let c, s, n = process_file_analysis config file_analysis in
      (c @ comp, s @ style, n @ naming))
    ([], [], []) file_analyses

let analyze_project config files rule_filter =
  let ml_files = List.filter (String.ends_with ~suffix:".ml") files in
  let all_files = files in
  let file_count = List.length ml_files in

  (* Run dune describe once at the beginning *)
  let dune_describe =
    Profiling.time "Dune describe" (fun () -> Dune.describe config.project_root)
  in

  (* Analyze all ML files with merlin once *)
  let file_analyses =
    Profiling.time "Merlin analysis (all files)" (fun () ->
        List.map
          (fun file ->
            ( file,
              Profiling.time (Fmt.str "Merlin: %s" file) (fun () ->
                  Merlin.analyze_file file) ))
          ml_files)
  in

  (* Run all analyses using the cached merlin results *)
  let complexity_issues, style_issues, naming_issues =
    Profiling.time "Aggregate issues" (fun () ->
        aggregate_issues config file_analyses)
  in

  (* Filter issues based on rule filter *)
  let complexity_issues_filtered =
    filter_issues rule_filter complexity_issues
  in
  let style_issues_filtered = filter_issues rule_filter style_issues in
  let naming_issues_filtered = filter_issues rule_filter naming_issues in

  (* Create reports with filtered issues *)
  let complexity_report =
    Profiling.time "Complexity report" (fun () ->
        Report.create
          ~rule_name:"Complexity rules (complexity ≤10, length ≤50, nesting ≤3)"
          ~passed:(complexity_issues_filtered = [])
          ~issues:complexity_issues_filtered ~file_count)
  in
  let style_report =
    Profiling.time "Style report" (fun () ->
        Report.create
          ~rule_name:"Style rules (no Obj.magic, no Str, no catch-all)"
          ~passed:(style_issues_filtered = [])
          ~issues:style_issues_filtered ~file_count)
  in
  let naming_report =
    Profiling.time "Naming report" (fun () ->
        Report.create ~rule_name:"Naming conventions (snake_case)"
          ~passed:(naming_issues_filtered = [])
          ~issues:naming_issues_filtered ~file_count)
  in

  let all_categories =
    [
      ( "Code Quality",
        [
          complexity_report;
          Profiling.time "Warning rules" (fun () ->
              run_warning_rules config all_files rule_filter);
        ] );
      ("Code Style", [ style_report ]);
      ("Naming Conventions", [ naming_report ]);
      ( "Documentation",
        [
          Profiling.time "Documentation rules" (fun () ->
              run_documentation_rules config all_files rule_filter);
        ] );
      ( "Project Structure",
        [
          Profiling.time "Format rules" (fun () ->
              run_format_rules config all_files rule_filter);
        ] );
      ( "Test Quality",
        [
          Profiling.time "Test convention rules" (fun () ->
              run_test_convention_rules config all_files rule_filter);
          Profiling.time "Test coverage rules" (fun () ->
              run_test_coverage_rules dune_describe all_files rule_filter);
        ] );
    ]
  in
  all_categories
