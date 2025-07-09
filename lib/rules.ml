(** Centralized rules coordinator for all merlint checks *)

type config = { merlint_config : Config.t; project_root : string }

let find_project_root file =
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

let run_complexity_rules config files =
  let issues = ref [] in
  let file_count = ref 0 in
  let complexity_config = Config.to_complexity_config config.merlint_config in

  List.iter
    (fun file ->
      incr file_count;
      match Merlin.dump_value "browse" file with
      | Ok browse_value ->
          let file_issues =
            Complexity.analyze_browse_value complexity_config
              browse_value
          in
          issues := file_issues @ !issues
      | Error _ -> ())
    files;

  Report.create
    ~rule_name:"Complexity rules (complexity ≤10, length ≤50, nesting ≤3)"
    ~passed:(!issues = []) ~issues:!issues ~file_count:!file_count

let run_style_rules _config files =
  let issues = ref [] in
  let file_count = ref 0 in

  List.iter
    (fun file ->
      incr file_count;
      match Merlin.dump_value "parsetree" file with
      | Ok structure ->
          let file_issues = Style.check structure in
          issues := file_issues @ !issues
      | Error _ -> ())
    files;

  Report.create ~rule_name:"Style rules (no Obj.magic, no Str, no catch-all)"
    ~passed:(!issues = []) ~issues:!issues ~file_count:!file_count

let run_naming_rules _config files =
  let issues = ref [] in
  let file_count = ref 0 in

  List.iter
    (fun file ->
      incr file_count;
      match Merlin.dump_value "parsetree" file with
      | Ok structure ->
          let file_issues = Naming.check structure in
          issues := file_issues @ !issues
      | Error _ -> ())
    files;

  Report.create ~rule_name:"Naming conventions (snake_case)"
    ~passed:(!issues = []) ~issues:!issues ~file_count:!file_count

let run_format_rules config files =
  let issues = Format.check config.project_root files in
  Report.create ~rule_name:"Format rules (.ocamlformat, .mli files)"
    ~passed:(issues = []) ~issues ~file_count:1

let run_documentation_rules _config files =
  let mli_files = List.filter (String.ends_with ~suffix:".mli") files in
  let issues = Doc.check_mli_files mli_files in

  Report.create ~rule_name:"Documentation rules (module docs)"
    ~passed:(issues = []) ~issues ~file_count:(List.length mli_files)

let analyze_project config files =
  let ml_files = List.filter (String.ends_with ~suffix:".ml") files in
  let all_files = files in

  let reports =
    [
      ("Code Quality", [ run_complexity_rules config ml_files ]);
      ("Code Style", [ run_style_rules config ml_files ]);
      ("Naming Conventions", [ run_naming_rules config ml_files ]);
      ("Documentation", [ run_documentation_rules config all_files ]);
      ("Project Structure", [ run_format_rules config all_files ]);
    ]
  in

  reports
