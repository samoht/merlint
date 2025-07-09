(** Centralized rules coordinator for all merlint checks *)

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

let run_format_rules config files =
  let issues = Format.check config.project_root files in
  Report.create ~rule_name:"Format rules (.ocamlformat, .mli files)"
    ~passed:(issues = []) ~issues ~file_count:1

let run_documentation_rules _config files =
  let mli_files = List.filter (String.ends_with ~suffix:".mli") files in
  let issues = Doc.check_mli_files mli_files in

  Report.create ~rule_name:"Documentation rules (module docs)"
    ~passed:(issues = []) ~issues ~file_count:(List.length mli_files)

(* Process a single file analysis *)
let process_file_analysis config (file, analysis) =
  let complexity_issues =
    match analysis.Merlin.browse with
    | Ok browse_value ->
        Complexity.analyze_browse_value
          (Config.to_complexity_config config.merlint_config)
          browse_value
    | Error _ -> []
  in

  let style_issues, naming_issues =
    match analysis.Merlin.parsetree with
    | Ok structure ->
        let style = Style.check structure in
        let outline =
          match analysis.Merlin.outline with Ok o -> Some o | Error _ -> None
        in
        let naming = Naming.check ~filename:file ~outline structure in
        (style, naming)
    | Error _ -> ([], [])
  in

  (complexity_issues, style_issues, naming_issues)

(* Aggregate issues from all file analyses *)
let aggregate_issues config file_analyses =
  List.fold_left
    (fun (comp, style, naming) file_analysis ->
      let c, s, n = process_file_analysis config file_analysis in
      (c @ comp, s @ style, n @ naming))
    ([], [], []) file_analyses

let analyze_project config files =
  let ml_files = List.filter (String.ends_with ~suffix:".ml") files in
  let all_files = files in
  let file_count = List.length ml_files in

  (* Analyze all ML files with merlin once *)
  let file_analyses =
    List.map (fun file -> (file, Merlin.analyze_file file)) ml_files
  in

  (* Run all analyses using the cached merlin results *)
  let complexity_issues, style_issues, naming_issues =
    aggregate_issues config file_analyses
  in

  (* Create reports *)
  let complexity_report =
    Report.create
      ~rule_name:"Complexity rules (complexity ≤10, length ≤50, nesting ≤3)"
      ~passed:(complexity_issues = []) ~issues:complexity_issues ~file_count
  in
  let style_report =
    Report.create ~rule_name:"Style rules (no Obj.magic, no Str, no catch-all)"
      ~passed:(style_issues = []) ~issues:style_issues ~file_count
  in
  let naming_report =
    Report.create ~rule_name:"Naming conventions (snake_case)"
      ~passed:(naming_issues = []) ~issues:naming_issues ~file_count
  in

  [
    ("Code Quality", [ complexity_report ]);
    ("Code Style", [ style_report ]);
    ("Naming Conventions", [ naming_report ]);
    ("Documentation", [ run_documentation_rules config all_files ]);
    ("Project Structure", [ run_format_rules config all_files ]);
  ]
