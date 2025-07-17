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
  with _ -> 120 (* fallback to 120 columns for tests *)

let make_relative_to_cwd path =
  match Fpath.of_string path with
  | Error _ -> path (* fallback to original path *)
  | Ok fpath -> (
      match Fpath.of_string (Sys.getcwd ()) with
      | Error _ -> path (* fallback to original path *)
      | Ok cwd -> (
          match Fpath.relativize ~root:cwd fpath with
          | Some rel -> Fpath.to_string rel
          | None -> path (* fallback to original path *)))

(* DEPRECATED: Use Merlint.Dune.get_project_files instead *)
let get_files_in_dir ~suffix dir =
  let rec get_files acc path =
    try
      let items = Sys.readdir path in
      Array.fold_left
        (fun acc item ->
          let full_path = Filename.concat path item in
          try
            if Sys.is_directory full_path then
              if
                item <> "_build" && item <> "_opam"
                && String.length item > 0
                && item.[0] <> '.'
              then get_files acc full_path
              else acc
            else if Filename.check_suffix item suffix then full_path :: acc
            else acc
          with Sys_error _ -> acc)
        acc items
    with Sys_error _ -> acc
  in
  get_files [] dir

let expand_paths ~suffix paths =
  List.fold_left
    (fun acc path ->
      if Sys.file_exists path then
        if Sys.is_directory path then get_files_in_dir ~suffix path @ acc
        else if Filename.check_suffix path suffix then path :: acc
        else acc
      else (
        Fmt.epr "Warning: %s does not exist@." path;
        acc))
    [] paths
  |> List.rev

let should_exclude_file file exclude_patterns =
  List.exists
    (fun pattern ->
      (* Simple pattern matching: check if pattern is contained in file path *)
      let pattern_parts = String.split_on_char '/' pattern in
      let file_parts = String.split_on_char '/' file in
      let rec matches_pattern pattern_parts file_parts =
        match (pattern_parts, file_parts) with
        | [], _ -> true
        | p :: ps, f :: fs when p = f -> matches_pattern ps fs
        | p :: ps, f :: fs when String.contains p '*' ->
            (* Simple glob support - * matches any string *)
            let prefix = String.sub p 0 (String.index p '*') in
            let suffix =
              String.sub p
                (String.index p '*' + 1)
                (String.length p - String.index p '*' - 1)
            in
            if String.starts_with ~prefix f && String.ends_with ~suffix f then
              matches_pattern ps fs
            else matches_pattern (p :: ps) fs
        | p :: ps, _ :: fs when p = "*" ->
            (* * matches any single path component *)
            matches_pattern ps fs || matches_pattern (p :: ps) fs
        | _ -> false
      in
      matches_pattern pattern_parts file_parts
      ||
      (* Also check simple substring matching for backwards compatibility *)
      let pattern_no_wildcards =
        String.concat "" (String.split_on_char '*' pattern)
      in
      String.length pattern_no_wildcards > 0
      && Re.execp (Re.compile (Re.str pattern_no_wildcards)) file)
    exclude_patterns

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
      Fmt.pr "  %a %a@."
        (Fmt.styled `Yellow Fmt.string)
        (Fmt.str "[%s]" error_code)
        (Fmt.styled `Bold Fmt.string)
        title;

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
            match Merlint.Rule.Run.location issue with
            | Some loc ->
                (* Format the issue with its pretty-printer *)
                let desc = Fmt.to_to_string Merlint.Rule.Run.pp issue in
                (* Always print location: description on same line *)
                (* Terminal will wrap naturally if too long *)
                Fmt.pr "  - %a: %s@."
                  (Fmt.styled `Bold Merlint.Location.pp)
                  loc desc
            | None -> ())
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

let run_analysis project_root filtered_files rule_filter show_profile =
  (* Set formatter margin based on terminal width *)
  let terminal_width = get_terminal_width () in
  Format.set_margin terminal_width;

  (* Reset profiling if enabled *)
  if show_profile then Merlint.Profiling.reset ();

  Log.info (fun m ->
      m "Starting visual analysis on %d files" (List.length filtered_files));

  (* Get exclude patterns from somewhere - for now empty *)
  let exclude_patterns = [] in

  (* Run the engine to get all issues *)
  let all_issues =
    match rule_filter with
    | Some filter ->
        Merlint.Engine.run ~filter ~exclude:exclude_patterns project_root
    | None -> (
        (* Create a default filter that enables all rules *)
        match Merlint.Filter.parse "all" with
        | Ok filter ->
            Merlint.Engine.run ~filter ~exclude:exclude_patterns project_root
        | Error _ -> [] (* Should not happen *))
  in

  Fmt.pr "Running merlint analysis...@.@.";
  Fmt.pr "Analyzing %d files@.@." (List.length filtered_files);

  (* Get all category names in order *)
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

  (* Group issues by category for reporting *)
  let issues_by_category =
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
  in

  (* Process each category *)
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
    issues_by_category;

  (* Create a dummy report for the summary *)
  let report =
    Merlint.Report.create ~rule_name:"All Rules"
      ~passed:(List.length all_issues = 0)
      ~issues:all_issues
      ~file_count:(List.length filtered_files)
  in
  Merlint.Report.print_summary [ report ];

  (* Print profiling summary if enabled *)
  if show_profile then (
    Merlint.Profiling.print_summary ();
    Merlint.Profiling.print_per_file_summary ());

  print_fix_hints all_issues

let ensure_project_built project_root =
  match Merlint.Dune.ensure_project_built project_root with
  | Ok () -> ()
  | Error msg ->
      Fmt.epr "Warning: %s@." msg;
      Fmt.epr "Function type analysis may not work properly.@.";
      Fmt.epr "Continuing with analysis...@."

let analyze_files ?(exclude_patterns = []) ?rule_filter ?(show_profile = false)
    files =
  (* Find project root and all files *)
  let project_root =
    match files with
    | file :: _ -> Merlint.Engine.get_project_root file
    | [] -> "."
  in

  Log.info (fun m -> m "Project root: %s" project_root);

  (* Ensure project is built before running merlin-based analyses *)
  ensure_project_built project_root;

  let all_files =
    if files = [] then
      (* Use dune describe to get project files *)
      let dune_describe = Merlint.Dune.describe project_root in
      Merlint.Dune.get_project_files dune_describe
    else expand_paths ~suffix:".ml" files @ expand_paths ~suffix:".mli" files
  in

  Log.debug (fun m ->
      m "Found %d total files before filtering" (List.length all_files));

  (* Convert to relative paths *)
  let all_files = List.map make_relative_to_cwd all_files in

  (* Filter out excluded files *)
  let filtered_files =
    if exclude_patterns = [] then all_files
    else
      List.filter
        (fun file ->
          let excluded = should_exclude_file file exclude_patterns in
          if excluded then Log.debug (fun m -> m "Excluding file: %s" file);
          not excluded)
        all_files
  in

  Log.info (fun m ->
      m "Analyzing %d files after exclusions" (List.length filtered_files));
  List.iter (fun file -> Log.debug (fun m -> m "  - %s" file)) filtered_files;

  run_analysis project_root filtered_files rule_filter show_profile

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
