(** Centralized rules coordinator - table-driven approach *)

exception Disabled of string

type config = { merlint_config : Config.t; project_root : string }

(* Rule types based on their data requirements *)
type rule_spec =
  | Browse of (config -> Browse.t -> Issue.t list)
  | Typedtree of (Typedtree.t -> Issue.t list)
  | TypedtreeContext of
      (filename:string ->
      outline:Outline.t option ->
      Typedtree.t ->
      Issue.t list)
  | Outline of (filename:string -> outline:Outline.t option -> Issue.t list)
  | Pattern of (string -> string -> Issue.t list)
    (* filename -> content -> issues *)
  | Files of (string list -> Issue.t list)
  | Project of (config -> string list -> Issue.t list)
  | Dune of (Dune.describe -> string list -> Issue.t list)

(* Map from issue type to its implementation *)
let get_implementation issue_type =
  match issue_type with
  (* Complexity Rules (E0xx) *)
  | Issue_type.Complexity ->
      Browse
        (fun config browse ->
          E001.check
            { E001.max_complexity = config.merlint_config.max_complexity }
            browse)
  | Issue_type.Function_length ->
      Browse
        (fun config browse ->
          E005.check
            {
              E005.max_function_length =
                config.merlint_config.max_function_length;
            }
            browse)
  | Issue_type.Deep_nesting ->
      Browse
        (fun config browse ->
          E010.check
            { E010.max_nesting = config.merlint_config.max_nesting }
            browse)
  (* Style Rules (E1xx) *)
  | Issue_type.Obj_magic -> Typedtree E100.check
  | Issue_type.Catch_all_exception -> Pattern E105.check
  | Issue_type.Silenced_warning -> Files E110.check
  (* Modern OCaml Rules (E2xx) *)
  | Issue_type.Str_module -> Typedtree E200.check
  | Issue_type.Printf_module -> Typedtree E205.check
  (* Naming Convention Rules (E3xx) *)
  | Issue_type.Variant_naming -> Typedtree E300.check
  | Issue_type.Module_naming -> Typedtree E305.check
  | Issue_type.Value_naming -> TypedtreeContext E310.check
  | Issue_type.Type_naming -> Typedtree E315.check
  | Issue_type.Long_identifier -> Typedtree E320.check
  | Issue_type.Function_naming -> Outline E325.check
  | Issue_type.Redundant_module_name -> Outline E330.check
  | Issue_type.Used_underscore_binding -> Typedtree E335.check
  | Issue_type.Error_pattern -> Pattern E340.check
  | Issue_type.Boolean_blindness -> TypedtreeContext E350.check
  | Issue_type.Mutable_state ->
      Outline
        (fun ~filename ~outline ->
          match outline with
          | Some o -> E351.check_global_mutable_state ~filename o
          | None -> [])
  (* Documentation Rules (E4xx) *)
  | Issue_type.Missing_mli_doc -> Files E400.check
  | Issue_type.Missing_value_doc -> Files E405.check
  | Issue_type.Bad_doc_style -> Files E410.check
  | Issue_type.Missing_standard_function -> Files E415.check
  (* Project Structure Rules (E5xx) *)
  | Issue_type.Missing_ocamlformat_file ->
      Project (fun config _files -> E500.check config.project_root)
  | Issue_type.Missing_mli_file ->
      Project (fun config files -> E505.check config.project_root files)
  | Issue_type.Missing_log_source -> Files E510.check
  (* Testing Rules (E6xx) *)
  | Issue_type.Test_exports_module -> Files E600.check
  | Issue_type.Missing_test_file -> Dune E605.check
  | Issue_type.Test_without_library -> Dune E610.check
  | Issue_type.Test_suite_not_included -> Dune E615.check

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
  let file_analyses =
    List.map (fun file -> (file, Merlin.analyze_file file)) ml_files
  in

  (* Run all rules from Data.all_rules *)
  let all_issues =
    List.concat_map
      (fun rule ->
        let spec = get_implementation rule.Rule.issue in
        safe_run (fun () ->
            match spec with
            | Browse check_fn ->
                List.concat_map
                  (fun (_file, analysis) ->
                    match analysis.Merlin.browse with
                    | Ok browse -> check_fn config browse
                    | Error _ -> [])
                  file_analyses
            | Typedtree check_fn ->
                List.concat_map
                  (fun (_file, analysis) ->
                    match analysis.Merlin.typedtree with
                    | Ok typedtree -> check_fn typedtree
                    | Error _ -> [])
                  file_analyses
            | TypedtreeContext check_fn ->
                List.concat_map
                  (fun (file, analysis) ->
                    match analysis.Merlin.typedtree with
                    | Ok typedtree ->
                        let outline =
                          match analysis.Merlin.outline with
                          | Ok o -> Some o
                          | Error _ -> None
                        in
                        check_fn ~filename:file ~outline typedtree
                    | Error _ -> [])
                  file_analyses
            | Outline check_fn ->
                List.concat_map
                  (fun (file, analysis) ->
                    let outline =
                      match analysis.Merlin.outline with
                      | Ok o -> Some o
                      | Error _ -> None
                    in
                    check_fn ~filename:file ~outline)
                  file_analyses
            | Pattern check_fn ->
                List.concat_map
                  (fun (file, _) ->
                    if String.ends_with ~suffix:".ml" file then
                      try
                        let content =
                          In_channel.with_open_text file In_channel.input_all
                        in
                        check_fn file content
                      with _ -> []
                    else [])
                  file_analyses
            | Files check_fn -> check_fn files
            | Project check_fn -> check_fn config files
            | Dune check_fn -> check_fn dune_describe files))
      Data.all_rules
  in

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
