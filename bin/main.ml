open Cmdliner

let logs_src = Logs.Src.create "merlint" ~doc:"Merlint OCaml linter"

module Log = (val Logs.src_log logs_src : Logs.LOG)

let setup_log ?style_renderer log_level =
  (* Setup logging with colors *)
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level log_level;
  Logs.set_reporter (Logs_fmt.reporter ~dst:Fmt.stderr ~app:Fmt.stdout ())

let check_ocamlmerlin () =
  let cmd = "which ocamlmerlin > /dev/null 2>&1" in
  match Unix.system cmd with Unix.WEXITED 0 -> true | _ -> false

let get_terminal_width () =
  try
    let ic = Unix.open_process_in "tput cols 2>/dev/null" in
    let width = int_of_string (input_line ic) in
    let _ = Unix.close_process_in ic in
    width
  with End_of_file | Failure _ | Sys_error _ ->
    120 (* fallback to 120 columns for tests *)

let wrap_text ?(indent = 2) ?(max_width = 120) text =
  let terminal_width = get_terminal_width () in
  let effective_width = min max_width terminal_width in
  let continuation_prefix = String.make indent ' ' in

  (* First normalize the text by joining all lines with spaces *)
  let normalized_text =
    text |> String.split_on_char '\n' |> List.map String.trim
    |> String.concat " "
  in

  let words = String.split_on_char ' ' normalized_text in
  let rec build_lines acc current_line current_length = function
    | [] -> if current_line = "" then acc else current_line :: acc
    | word :: rest ->
        let word_len = String.length word in
        let space_len = if current_line = "" then 0 else 1 in
        let new_length = current_length + space_len + word_len in
        if new_length + indent <= effective_width then
          let new_line =
            if current_line = "" then word else current_line ^ " " ^ word
          in
          build_lines acc new_line new_length rest
        else
          let completed_line =
            if current_line = "" then word else current_line
          in
          build_lines (completed_line :: acc) word word_len rest
  in
  let lines = List.rev (build_lines [] "" 0 words) in
  match lines with
  | [] -> ""
  | lines ->
      String.concat "\n"
        (List.map (fun line -> continuation_prefix ^ line) lines)

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
        (Fmt.styled `Yellow Fmt.string)
        (Fmt.str "[%s]" error_code)
        (Fmt.styled `Bold Fmt.string)
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
                 Fmt.pr "%a@." (Fmt.styled `Faint Fmt.string) line)
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
let get_enabled_rules rule_filter =
  match rule_filter with
  | Some filter ->
      List.filter
        (fun rule ->
          Merlint.Filter.is_enabled_by_code filter (Merlint.Rule.code rule))
        Merlint.Data.all_rules
  | None -> Merlint.Data.all_rules

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
  (* Set formatter margin based on terminal width *)
  let terminal_width = get_terminal_width () in
  Format.set_margin terminal_width;

  (* Reset profiling if enabled *)
  if show_profile then Merlint.Profiling.reset ();

  let files_count =
    List.length (Merlint.Dune.get_project_files dune_describe)
  in
  Log.info (fun m -> m "Starting visual analysis on %d files" files_count);

  (* Run the engine to get all issues *)
  let all_issues =
    match rule_filter with
    | Some filter -> Merlint.Engine.run ~filter ~dune_describe project_root
    | None -> (
        (* Create a default filter that enables all rules *)
        match Merlint.Filter.parse "all" with
        | Ok filter -> Merlint.Engine.run ~filter ~dune_describe project_root
        | Error _ -> [] (* Should not happen *))
  in

  Fmt.pr "Running merlint analysis...@.@.";
  Fmt.pr "Analyzing %d files@.@." files_count;

  (* Group issues by category for reporting *)
  let issues_by_category = group_issues_by_category all_issues in

  (* Process each category *)
  print_categorized_issues issues_by_category;

  (* Calculate the actual number of rules that were applied *)
  let enabled_rules = get_enabled_rules rule_filter in
  let enabled_rule_count = List.length enabled_rules in

  (* Print custom summary *)
  print_summary all_issues enabled_rule_count;

  (* Print profiling summary if enabled *)
  if show_profile then (
    Merlint.Profiling.print_summary ();
    Merlint.Profiling.print_per_file_summary ());

  print_fix_hints all_issues

let ensure_project_built project_root =
  match Merlint.Dune.ensure_project_built (Fpath.v project_root) with
  | Ok () -> ()
  | Error msg ->
      Fmt.epr "Warning: %s@." msg;
      Fmt.epr "Function type analysis may not work properly.@.";
      Fmt.epr "Continuing with analysis...@."

let analyze_files ?(exclude_patterns = []) ?rule_filter ?(show_profile = false)
    files =
  (* Find project root *)
  let project_root =
    match files with
    | file :: _ -> Merlint.Engine.get_project_root file
    | [] -> "."
  in

  Log.info (fun m -> m "Project root: %s" project_root);

  (* Ensure project is built before running merlin-based analyses *)
  ensure_project_built project_root;

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
          Merlint.Dune.create_synthetic (List.rev !explicit_files)
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

let log_level =
  let env = Cmd.Env.info "MERLINT_VERBOSE" in
  Logs_cli.level ~env ()

let profile_flag =
  let doc = "Show profiling statistics for analysis operations" in
  Arg.(value & flag & info [ "profile"; "p" ] ~doc)

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
  let info = Cmd.info "merlint" ~version:"0.1.0" ~doc ~man in
  Cmd.v info
    Term.(
      const
        (fun
          style_renderer
          log_level
          exclude_patterns
          rules_spec
          show_profile
          files
        ->
          setup_log ?style_renderer log_level;
          if not (check_ocamlmerlin ()) then (
            Log.err (fun m -> m "ocamlmerlin not found in PATH");
            Log.err (fun m -> m "To fix this, run one of the following:");
            Log.err (fun m -> m "  1. eval $(opam env)  # If using opam");
            Log.err (fun m ->
                m "  2. opam install merlin  # If merlin is not installed");
            Stdlib.exit 1)
          else
            (* Parse rule filter if provided *)
            let rule_filter =
              match rules_spec with
              | None -> None
              | Some spec -> (
                  match Merlint.Filter.parse spec with
                  | Ok filter -> Some filter
                  | Error msg ->
                      Log.err (fun m -> m "Invalid rules specification: %s" msg);
                      Stdlib.exit 1)
            in
            analyze_files ~exclude_patterns ?rule_filter ~show_profile files)
      $ Fmt_cli.style_renderer () $ log_level $ exclude_flag $ rules_flag
      $ profile_flag $ files)

let () = Stdlib.exit (Cmd.eval cmd)
