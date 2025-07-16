(** Centralized rules coordinator - context-based approach *)

exception Disabled of string

type config = { merlint_config : Config.t; project_root : string }

(* Map from issue kind to file-level implementation *)
let get_file_implementation (kind : Issue.kind) =
  match kind with
  (* Complexity Rules (E0xx) *)
  | Complexity -> Some E001.check
  | Function_length -> Some E005.check
  | Deep_nesting -> Some E010.check
  (* Style Rules (E1xx) *)
  | Obj_magic -> Some E100.check
  | Catch_all_exception -> Some E105.check
  (* Modern OCaml Rules (E2xx) *)
  | Str_module -> Some E200.check
  | Printf_module -> Some E205.check
  (* Naming Convention Rules (E3xx) *)
  | Variant_naming -> Some E300.check
  | Module_naming -> Some E305.check
  | Value_naming -> Some E310.check
  | Type_naming -> Some E315.check
  | Long_identifier -> Some E320.check
  | Function_naming -> Some E325.check
  | Redundant_module_name -> Some E330.check
  | Used_underscore_binding -> Some E335.check
  | Error_pattern -> Some E340.check
  | Boolean_blindness -> Some E350.check
  | Mutable_state -> Some E351.check
  (* Documentation Rules (E4xx) *)
  | Missing_value_doc -> Some E405.check
  | Bad_doc_style -> Some E410.check
  | Missing_standard_function -> Some E415.check
  (* Project Structure Rules (E5xx) *)
  | Missing_log_source -> Some E510.check
  (* All other rules are project-level *)
  | _ -> None

(* Map from issue kind to project-level implementation *)
let get_project_implementation (kind : Issue.kind) =
  match kind with
  (* Style Rules (E1xx) *)
  | Silenced_warning -> Some E110.check
  (* Documentation Rules (E4xx) *)
  | Missing_mli_doc -> Some E400.check
  (* Project Structure Rules (E5xx) *)
  | Missing_ocamlformat_file -> Some E500.check
  | Missing_mli_file -> Some E505.check
  (* Testing Rules (E6xx) *)
  | Test_exports_module -> Some E600.check
  | Missing_test_file -> Some E605.check
  | Test_without_library -> Some E610.check
  | Test_suite_not_included -> Some E615.check
  (* All other rules are file-level *)
  | _ -> None

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

  (* Analyze each file and run file-level rules *)
  let all_issues =
    List.concat_map
      (fun file ->
        let merlin_result = Merlin.analyze_file file in

        (* Create file context for this file *)
        let ctx =
          Context.create_file ~filename:file ~config:config.merlint_config
            ~project_root:config.project_root ~merlin_result
        in

        (* Run all file-level rules on this file *)
        List.concat_map
          (fun rule ->
            match
              (rule.Rule.scope, get_file_implementation rule.Rule.issue)
            with
            | Rule.File, Some impl -> safe_run (fun () -> impl ctx)
            | File, None -> failwith "invalid get_file_implementation"
            | _ -> [])
          Data.all_rules)
      ml_files
  in

  (* Run project-wide rules once *)
  let project_ctx =
    Context.create_project ~config:config.merlint_config
      ~project_root:config.project_root ~all_files:files ~dune_describe
  in
  let project_issues =
    List.concat_map
      (fun rule ->
        match (rule.Rule.scope, get_project_implementation rule.Rule.issue) with
        | Rule.Project, Some impl -> safe_run (fun () -> impl project_ctx)
        | Project, None -> failwith "invalid get_project_implementation"
        | _ -> [])
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
