open Cmdliner

let logs_src = Logs.Src.create "merlint" ~doc:"Merlint OCaml linter"

module Log = (val Logs.src_log logs_src : Logs.LOG)

let wrap_text ?(indent = 2) text =
  Tty.Width.wrap ~indent (Tty.Width.terminal_width ()) text

let print_issue_group (error_code, issues) =
  (* Sort issues within each group by location *)
  let sorted_issues = List.sort Merlint.Rule.Run.compare issues in
  match sorted_issues with
  | [] -> ()
  | first_issue :: _ ->
      (* Get title from the first issue *)
      let title = Merlint.Rule.Run.title first_issue in
      let issue_count = List.length sorted_issues in
      let issue_word = if issue_count = 1 then "issue" else "issues" in
      Fmt.pr "  %a %a (%d %s)@."
        (Tty.Style.styled Tty.Style.(fg Tty.Color.yellow) Fmt.string)
        (Fmt.str "[%s]" error_code)
        (Tty.Style.styled Tty.Style.bold Fmt.string)
        title issue_count issue_word;

      (* Find the rule to get the hint *)
      let rule_opt =
        List.find_opt
          (fun rule -> Merlint.Rule.code rule = error_code)
          Merlint.Data.all_rules
      in
      (match rule_opt with
      | Some rule ->
          let hint = Merlint.Rule.hint rule in
          let wrapped_hint = wrap_text ~indent:2 hint in
          (* Print each line of the hint in gray *)
          String.split_on_char '\n' wrapped_hint
          |> List.iter (fun line ->
              Fmt.pr "%a@." (Tty.Style.styled Tty.Style.faint Fmt.string) line)
      | None -> ());

      (* Print each issue with location and description *)
      if List.length sorted_issues > 0 then
        List.iter
          (fun issue ->
            (* Print the issue using its pretty-printer, which already includes location *)
            Fmt.pr "  - %a@." Merlint.Rule.Run.pp issue)
          sorted_issues

(** Group issues by error code *)
let group_issues_by_code issues =
  List.fold_left
    (fun acc issue ->
      let error_code = Merlint.Rule.Run.code issue in
      let current =
        match List.assoc_opt error_code acc with
        | Some issues -> issues
        | None -> []
      in
      (error_code, issue :: current) :: List.remove_assoc error_code acc)
    [] issues

let print_fix_hints all_issues = if all_issues <> [] then exit 1

(* Group issues by category for visual reporting *)
let group_issues_by_category all_issues =
  let all_categories =
    [
      "Code Quality";
      "Code Style";
      "Naming Conventions";
      "Documentation";
      "Project Structure";
      "Test Quality";
    ]
  in
  List.map
    (fun category_name ->
      let category_issues =
        List.filter
          (fun issue ->
            let code = Merlint.Rule.Run.code issue in
            (* Find the rule to get its category *)
            match
              List.find_opt
                (fun r -> Merlint.Rule.code r = code)
                Merlint.Data.all_rules
            with
            | Some rule ->
                let category = Merlint.Rule.category rule in
                Merlint.Rule.category_name category = category_name
            | None -> false)
          all_issues
      in
      (category_name, category_issues))
    all_categories

(* Print issues grouped by category *)
let print_categorized_issues issues_by_category =
  List.iter
    (fun (category_name, issues) ->
      let total_issues = List.length issues in
      let category_passed = total_issues = 0 in

      Fmt.pr "%s %s (%d total issues)@."
        (Merlint.Report.print_color category_passed
           (Merlint.Report.print_status category_passed))
        category_name total_issues;

      (* Group by error code and print *)
      if total_issues > 0 then
        let grouped_issues = group_issues_by_code issues in
        let sorted_groups =
          List.sort (fun (a, _) (b, _) -> String.compare a b) grouped_issues
        in
        List.iter print_issue_group sorted_groups)
    issues_by_category

(* Get enabled rules based on filter *)
let enabled_rules rule_filter =
  match rule_filter with
  | Some filter ->
      List.filter
        (fun rule ->
          Merlint.Filter.is_enabled_by_code filter (Merlint.Rule.code rule))
        Merlint.Data.all_rules
  | None -> Merlint.Data.all_rules

(* Print summary table by category *)
let print_summary_table issues_by_category =
  (* Build summary data for each category *)
  let rows =
    List.filter_map
      (fun (category_name, issues) ->
        let count = List.length issues in
        if count = 0 then None
        else
          (* Group by error code to get breakdown *)
          let by_code = group_issues_by_code issues in
          let breakdown =
            List.map
              (fun (code, code_issues) ->
                let n = List.length code_issues in
                (* Get the title from the rule *)
                let title =
                  match
                    List.find_opt
                      (fun r -> Merlint.Rule.code r = code)
                      Merlint.Data.all_rules
                  with
                  | Some rule -> Merlint.Rule.title rule
                  | None -> code
                in
                Fmt.str "%d %s" n (String.lowercase_ascii title))
              by_code
          in
          let details =
            if List.length breakdown <= 2 then String.concat ", " breakdown
            else
              let first_two = List.filteri (fun i _ -> i < 2) breakdown in
              Fmt.str "%s, ..." (String.concat ", " first_two)
          in
          Some [ category_name; Fmt.str "%d (%s)" count details ])
      issues_by_category
  in
  if rows <> [] then (
    Fmt.pr "@.";
    let term_width = Tty.Width.terminal_width () in
    (* Account for borders and padding: 2 borders + 2 middle + 4 padding = 8 *)
    let available = term_width - 8 in
    let cat_width = min 20 (available / 4) in
    let issues_width = available - cat_width in
    let columns =
      [
        Tty.Table.column ~align:`Left ~max_width:cat_width "Category";
        Tty.Table.column ~align:`Left ~max_width:issues_width "Issues";
      ]
    in
    let table =
      Tty.Table.of_string_rows ~border:Tty.Border.rounded columns rows
    in
    Fmt.pr "%a@." Tty.Table.pp table)

(* Print summary and status *)
let print_summary all_issues enabled_rule_count =
  let total_issues = List.length all_issues in
  let all_passed = total_issues = 0 in
  let rule_word = if enabled_rule_count = 1 then "rule" else "rules" in

  Fmt.pr "@.Summary: %s %d total %s (applied %d %s)@."
    (Merlint.Report.print_color all_passed
       (Merlint.Report.print_status all_passed))
    total_issues
    (if total_issues = 1 then "issue" else "issues")
    enabled_rule_count rule_word;

  if all_passed then
    Fmt.pr "%s All checks passed!@." (Merlint.Report.print_color true "✓")
  else
    Fmt.pr "%s Some checks failed. See details above.@."
      (Merlint.Report.print_color false "✗")

let run_analysis project_root dune_describe rule_filter show_profile =
  (* Create profiling state if enabled *)
  let profiling_state =
    if show_profile then Some (Merlint.Profiling.v ()) else None
  in

  let files_count = List.length (Merlint.Dune.project_files dune_describe) in
  Log.info (fun m -> m "Starting visual analysis on %d files" files_count);

  (* Run the engine to get all issues *)
  let all_issues =
    match rule_filter with
    | Some filter ->
        Merlint.Engine.run ~filter ~dune_describe ?profiling:profiling_state
          project_root
    | None -> (
        (* Create a default filter that enables all rules *)
        match Merlint.Filter.parse "all" with
        | Ok filter ->
            Merlint.Engine.run ~filter ~dune_describe ?profiling:profiling_state
              project_root
        | Error _ -> [] (* Should not happen *))
  in

  Fmt.pr "Running merlint analysis...@.@.";
  Fmt.pr "Analyzing %d files@.@." files_count;

  (* Group issues by category for reporting *)
  let issues_by_category = group_issues_by_category all_issues in

  (* Process each category *)
  print_categorized_issues issues_by_category;

  (* Print summary table *)
  print_summary_table issues_by_category;

  (* Calculate the actual number of rules that were applied *)
  let enabled_rules = enabled_rules rule_filter in
  let enabled_rule_count = List.length enabled_rules in

  (* Print custom summary *)
  print_summary all_issues enabled_rule_count;

  (* Print profiling summary if enabled *)
  match profiling_state with
  | Some state ->
      Merlint.Profiling.print_summary state;
      Merlint.Profiling.print_rule_summary state;
      Merlint.Profiling.print_file_summary state
  | None ->
      ();

      print_fix_hints all_issues

let ensure_project_built project_root =
  match Merlint.Dune.ensure_project_built (Fpath.v project_root) with
  | Ok () -> ()
  | Error msg ->
      Fmt.epr "Warning: %s@." msg;
      Fmt.epr "Function type analysis may not work properly.@.";
      Fmt.epr "Continuing with analysis...@."

let analyze_files ?(exclude_patterns = []) ?rule_filter ?(show_profile = false)
    ?(no_build = false) files =
  (* Find project root *)
  let project_root =
    match files with file :: _ -> Merlint.Project.root file | [] -> "."
  in

  Log.info (fun m -> m "Project root: %s" project_root);

  (* Ensure project is built before running merlin-based analyses *)
  if not no_build then ensure_project_built project_root;

  (* Build dune describes from directories/files *)
  let dune_describe =
    match files with
    | [] ->
        (* No files specified, use dune for the project root *)
        Merlint.Dune.describe (Fpath.v project_root)
    | _ ->
        (* Files or directories specified *)
        let describes = ref [] in
        let explicit_files = ref [] in
        List.iter
          (fun path ->
            if Sys.file_exists path && Sys.is_directory path then
              (* For directories, create a dune describe *)
              let desc = Merlint.Dune.describe (Fpath.v path) in
              describes := desc :: !describes
            else if Sys.file_exists path then
              (* For individual files, we need to create a describe with them *)
              if
                Filename.check_suffix path ".ml"
                || Filename.check_suffix path ".mli"
              then explicit_files := path :: !explicit_files
              else ()
            else Fmt.epr "Warning: %s does not exist@." path)
          files;

        (* If we have explicit files but no describes, create a synthetic describe *)
        if !describes = [] && !explicit_files <> [] then
          (* Create a synthetic describe with the files as executables *)
          Merlint.Dune.synthetic (List.rev !explicit_files)
        else
          (* Merge all describes *)
          Merlint.Dune.merge (List.rev !describes)
  in

  (* Apply exclusions (including cram directories which are already filtered) *)
  let filtered_describe =
    if exclude_patterns = [] then dune_describe
    else Merlint.Dune.exclude exclude_patterns dune_describe
  in

  run_analysis project_root filtered_describe rule_filter show_profile

let files =
  let doc =
    "OCaml source files or directories to analyze. If none specified, analyzes \
     all .ml and .mli files in the current dune project."
  in
  Arg.(value & pos_all string [] & info [] ~docv:"FILE|DIR" ~doc)

let exclude_flag =
  let doc =
    "Exclude files matching these patterns (can be used multiple times). \
     Supports simple glob patterns with * and path matching."
  in
  Arg.(value & opt_all string [] & info [ "exclude"; "e" ] ~docv:"PATTERN" ~doc)

let rules_flag =
  let doc =
    "Filter rules to enable/disable specific checks. Simple format: --rules \
     all-E110-E205 (all except E110 and E205), --rules E300+E305 (only these \
     two), --rules all-100..199 (all except codes 100-199). No quotes needed!"
  in
  Arg.(value & opt (some string) None & info [ "rules"; "r" ] ~docv:"SPEC" ~doc)

let profile_flag =
  let doc = "Show profiling statistics for analysis operations" in
  Arg.(value & flag & info [ "profile"; "p" ] ~doc)

let show_config_flag =
  let doc =
    "Show the loaded configuration and exit (useful for debugging .merlint \
     files)"
  in
  Arg.(value & flag & info [ "show-config" ] ~doc)

let no_build_flag =
  let doc =
    "Skip the automatic 'dune build' step. Use when the project is already \
     built or for faster repeated runs."
  in
  Arg.(value & flag & info [ "no-build"; "B" ] ~doc)

let show_configuration files =
  let project_root =
    match files with
    | [] -> Merlint.Project.root (Sys.getcwd ())
    | path :: _ -> Merlint.Project.root path
  in
  let config = Merlint.Config.load_from_path project_root in
  Fmt.pr "=== Merlint Configuration ===@.";
  Fmt.pr "Project root: %s@." project_root;
  let config_file = Merlint.Config.file project_root in
  (match config_file with
  | Some path -> Fmt.pr "Config file: %s (found)@." path
  | None -> Fmt.pr "Config file: .merlint (not found, using defaults)@.");
  Fmt.pr "@.Settings:@.";
  Fmt.pr "  max-complexity: %d@." config.max_complexity;
  Fmt.pr "  max-function-length: %d@." config.max_function_length;
  Fmt.pr "  max-nesting: %d@." config.max_nesting;
  Fmt.pr "  exempt-data-definitions: %b@." config.exempt_data_definitions;
  Fmt.pr "  max-underscores-in-name: %d@." config.max_underscores_in_name;
  Fmt.pr "  min-name-length-underscore: %d@." config.min_name_length_underscore;
  Fmt.pr "  allow-obj-magic: %b@." config.allow_obj_magic;
  Fmt.pr "  allow-str-module: %b@." config.allow_str_module;
  Fmt.pr "  allow-catch-all-exceptions: %b@." config.allow_catch_all_exceptions;
  Fmt.pr "  require-ocamlformat-file: %b@." config.require_ocamlformat_file;
  Fmt.pr "  require-mli-files: %b@." config.require_mli_files;
  Fmt.pr "@.Exclusions:@.";
  if config.exclusions = Merlint.Rule_config.empty then Fmt.pr "  (none)@."
  else Fmt.pr "  %a@." Merlint.Rule_config.pp config.exclusions;
  Stdlib.exit 0

let parse_rule_filter rules_spec =
  match rules_spec with
  | None -> None
  | Some spec -> (
      match Merlint.Filter.parse spec with
      | Ok filter -> Some filter
      | Error msg ->
          Log.err (fun m -> m "Invalid rules specification: %s" msg);
          Stdlib.exit 1)

let main exclude_patterns rules_spec show_profile show_config no_build files ()
    =
  if show_config then show_configuration files
  else
    let rule_filter = parse_rule_filter rules_spec in
    analyze_files ~exclude_patterns ?rule_filter ~show_profile ~no_build files

let cmd =
  let doc = "Analyze OCaml code for style issues" in
  let man =
    [
      `S Manpage.s_description;
      `P
        "$(tname) analyzes OCaml source files and reports issues with modern \
         OCaml coding conventions.";
      `P
        "It uses Merlin to parse the OCaml AST and checks for naming \
         conventions, complexity, documentation, and code style issues.";
      `P
        "If no files or directories are specified, it analyzes all .ml and \
         .mli files in the current dune project (searching upward for \
         dune-project).";
    ]
  in
  let info = Cmd.info "merlint" ~version:Monopam_info.version ~doc ~man in
  Cmd.v info
    Term.(
      const main $ exclude_flag $ rules_flag $ profile_flag $ show_config_flag
      $ no_build_flag $ files $ Vlog.setup "merlint")

let () = Stdlib.exit (Cmd.eval cmd)
