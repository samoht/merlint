(** Centralized rules coordinator - context-based approach *)

exception Disabled of string

type config = { merlint_config : Config.t; project_root : string }

(* Map from issue type to its implementation *)
let get_implementation = function
  (* Complexity Rules (E0xx) *)
  | Issue_type.Complexity -> E001.check
  | Issue_type.Function_length -> E005.check
  | Issue_type.Deep_nesting -> E010.check
  (* Style Rules (E1xx) *)
  | Issue_type.Obj_magic -> E100.check
  | Issue_type.Catch_all_exception -> E105.check
  | Issue_type.Silenced_warning -> E110.check
  (* Modern OCaml Rules (E2xx) *)
  | Issue_type.Str_module -> E200.check
  | Issue_type.Printf_module -> E205.check
  (* Naming Convention Rules (E3xx) *)
  | Issue_type.Variant_naming -> E300.check
  | Issue_type.Module_naming -> E305.check
  | Issue_type.Value_naming -> E310.check
  | Issue_type.Type_naming -> E315.check
  | Issue_type.Long_identifier -> E320.check
  | Issue_type.Function_naming -> E325.check
  | Issue_type.Redundant_module_name -> E330.check
  | Issue_type.Used_underscore_binding -> E335.check
  | Issue_type.Error_pattern -> E340.check
  | Issue_type.Boolean_blindness -> E350.check
  | Issue_type.Mutable_state -> E351.check
  (* Documentation Rules (E4xx) *)
  | Issue_type.Missing_mli_doc -> E400.check
  | Issue_type.Missing_value_doc -> E405.check
  | Issue_type.Bad_doc_style -> E410.check
  | Issue_type.Missing_standard_function -> E415.check
  (* Project Structure Rules (E5xx) *)
  | Issue_type.Missing_ocamlformat_file -> E500.check
  | Issue_type.Missing_mli_file -> E505.check
  | Issue_type.Missing_log_source -> E510.check
  (* Testing Rules (E6xx) *)
  | Issue_type.Test_exports_module -> E600.check
  | Issue_type.Missing_test_file -> E605.check
  | Issue_type.Test_without_library -> E610.check
  | Issue_type.Test_suite_not_included -> E615.check

(* Helper functions *)
let get_project_root file =
  let rec find_root dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then dir else find_root parent
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

let safe_run fn = try fn () with Issue.Disabled _ -> []

(* Main analysis function *)
let analyze_project config files rule_filter =
  let ml_files = List.filter (String.ends_with ~suffix:".ml") files in
  let file_count = List.length ml_files in

  (* Prepare shared data *)
  let dune_describe = Dune.describe config.project_root in

  (* Analyze each file and run rules *)
  let all_issues =
    List.concat_map
      (fun file ->
        let merlin_result = Merlin.analyze_file file in

        (* Create file context for this file *)
        let ctx =
          Context.File
            (Context.create_file ~filename:file ~config:config.merlint_config
               ~project_root:config.project_root ~merlin_result)
        in

        (* Run all rules on this file *)
        List.concat_map
          (fun rule ->
            match rule.Rule.scope with
            | Rule.Project -> [] (* Skip project rules in file iteration *)
            | Rule.File ->
                let impl = get_implementation rule.Rule.issue in
                safe_run (fun () -> impl ctx))
          Data.all_rules)
      ml_files
  in

  (* Run project-wide rules once *)
  let project_ctx =
    Context.Project
      (Context.create_project ~config:config.merlint_config
         ~project_root:config.project_root ~all_files:files ~dune_describe)
  in

  let project_issues =
    List.concat_map
      (fun rule ->
        match rule.Rule.scope with
        | Rule.File -> [] (* Skip file rules in project iteration *)
        | Rule.Project ->
            let impl = get_implementation rule.Rule.issue in
            safe_run (fun () -> impl project_ctx))
      Data.all_rules
  in

  let all_issues = all_issues @ project_issues in

  (* Filter and categorize issues *)
  let filtered_issues = filter_issues rule_filter all_issues in

  (* Create reports organized by rule categories *)
  (* Group issues by their rule category *)
  let category_issues = Hashtbl.create 10 in
  List.iter
    (fun issue ->
      let issue_type = Issue.get_type issue in
      let rule = Rule.get Data.all_rules issue_type in
      let current =
        try Hashtbl.find category_issues rule.Rule.category
        with Not_found -> []
      in
      Hashtbl.replace category_issues rule.Rule.category (issue :: current))
    filtered_issues;

  (* Helper to get issues for a category *)
  let get_category_issues category =
    try Hashtbl.find category_issues category with Not_found -> []
  in

  (* Generate one report per category *)
  let categories =
    [
      ( Rule.Complexity,
        "Complexity rules (complexity ≤10, length ≤50, nesting ≤3)",
        file_count );
      ( Rule.Security_safety,
        "Security rules (no Obj.magic, no catch-all)",
        file_count );
      ( Rule.Style_modernization,
        "Style rules (no Str module, modern patterns)",
        file_count );
      (Rule.Naming_conventions, "Naming conventions (snake_case)", file_count);
      ( Rule.Documentation,
        "Documentation rules (module docs)",
        List.length (List.filter (String.ends_with ~suffix:".mli") files) );
      (Rule.Project_structure, "Format rules (.ocamlformat, .mli files)", 1);
      (Rule.Testing, "Test quality rules", file_count);
    ]
  in

  (* Group reports by display name *)
  let display_groups = Hashtbl.create 10 in
  List.iter
    (fun (category, rule_name, count) ->
      let display_name = Rule.category_name category in
      let report =
        Report.create ~rule_name
          ~passed:(get_category_issues category = [])
          ~issues:(get_category_issues category)
          ~file_count:count
      in
      let current =
        try Hashtbl.find display_groups display_name with Not_found -> []
      in
      Hashtbl.replace display_groups display_name (report :: current))
    categories;

  (* Convert to list of (display_name, reports) *)
  Rule.
    [
      category_name Complexity;
      category_name Security_safety;
      category_name Naming_conventions;
      category_name Documentation;
      category_name Project_structure;
      category_name Testing;
    ]
  |> List.filter_map (fun display_name ->
         match Hashtbl.find_opt display_groups display_name with
         | None -> None
         | Some reports -> Some (display_name, List.rev reports))
