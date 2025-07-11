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

let process_category_report (category_name, reports) =
  let total_issues =
    List.fold_left
      (fun acc report -> acc + List.length report.Merlint.Report.issues)
      0 reports
  in
  let category_passed =
    List.for_all (fun report -> report.Merlint.Report.passed) reports
  in

  Fmt.pr "%s %s (%d total issues)@."
    (Merlint.Report.print_color category_passed
       (Merlint.Report.print_status category_passed))
    category_name total_issues;

  (* Only show detailed reports if there are issues *)
  if total_issues > 0 then List.iter Merlint.Report.print_detailed reports;
  reports

let wrap_hint_description ?(max_width = 120) text =
  let terminal_width = get_terminal_width () in
  let effective_width = min max_width terminal_width in
  let indent_size = 2 in
  let continuation_prefix = String.make indent_size ' ' in

  let words = String.split_on_char ' ' text in
  let rec build_lines acc current_line current_length = function
    | [] -> if current_line = "" then acc else current_line :: acc
    | word :: rest ->
        let word_len = String.length word in
        let space_len = if current_line = "" then 0 else 1 in
        let new_length = current_length + space_len + word_len in
        if new_length <= effective_width - indent_size then
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

let print_fix_hints all_issues =
  if all_issues <> [] then (
    Fmt.pr "@.%a Fix hints:@.@."
      (Fmt.styled `Bold (Fmt.styled `Yellow Fmt.string))
      "💡";

    (* Group issues by type and provide contextual hints *)
    let module Issue_type_map = Map.Make (struct
      type t = Merlint.Issue_type.t

      let compare = compare
    end) in
    let issue_groups =
      List.fold_left
        (fun acc issue ->
          let issue_type = Merlint.Issue.get_type issue in
          let current =
            match Issue_type_map.find_opt issue_type acc with
            | None -> []
            | Some issues -> issues
          in
          Issue_type_map.add issue_type (issue :: current) acc)
        Issue_type_map.empty all_issues
    in

    (* Print grouped hints with issues sorted by severity *)
    let first = ref true in
    Issue_type_map.iter
      (fun issue_type issues ->
        let sorted_issues = List.sort Merlint.Issue.compare issues in
        let hint = Merlint.Issue.get_grouped_hint issue_type sorted_issues in
        if not !first then Fmt.pr "@.";
        (* Add spacing between hints *)
        first := false;
        let error_code = Merlint.Issue.error_code issue_type in
        let title = Merlint.Hints.get_hint_title issue_type in
        (* Print error code in yellow with title *)
        Fmt.pr "%a %a@."
          (Fmt.styled `Yellow Fmt.string)
          (Fmt.str "[%s]" error_code)
          (Fmt.styled `Bold Fmt.string)
          title;
        (* Print wrapped description *)
        Fmt.pr "%s@." (wrap_hint_description hint))
      issue_groups;

    exit 1)

let run_analysis project_root filtered_files =
  (* Set formatter margin based on terminal width *)
  let terminal_width = get_terminal_width () in
  Format.set_margin terminal_width;

  let rules_config = Merlint.Rules.default_config project_root in
  Log.info (fun m ->
      m "Starting visual analysis on %d files" (List.length filtered_files));
  let category_reports =
    Merlint.Rules.analyze_project rules_config filtered_files
  in

  Fmt.pr "Running merlint analysis...@.@.";
  Fmt.pr "Analyzing %d files@.@." (List.length filtered_files);

  let all_reports =
    List.fold_left
      (fun acc category_report ->
        let reports = process_category_report category_report in
        reports @ acc)
      [] category_reports
  in

  Merlint.Report.print_summary all_reports;
  let all_issues = Merlint.Report.get_all_issues all_reports in
  print_fix_hints all_issues

let ensure_project_built project_root =
  match Merlint.Dune.ensure_project_built project_root with
  | Ok () -> ()
  | Error msg ->
      Fmt.epr "Warning: %s@." msg;
      Fmt.epr "Function type analysis may not work properly.@.";
      Fmt.epr "Continuing with analysis...@."

let analyze_files ?(exclude_patterns = []) files =
  (* Find project root and all files *)
  let project_root =
    match files with
    | file :: _ -> Merlint.Rules.get_project_root file
    | [] -> "."
  in

  Log.info (fun m -> m "Project root: %s" project_root);

  (* Ensure project is built before running merlin-based analyses *)
  ensure_project_built project_root;

  let all_files =
    if files = [] then
      (* Use dune describe to get project files *)
      Merlint.Dune.get_project_files project_root
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

  run_analysis project_root filtered_files

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

let log_level =
  let env = Cmd.Env.info "MERLINT_VERBOSE" in
  Logs_cli.level ~env ()

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
      const (fun style_renderer log_level exclude_patterns files ->
          setup_log ?style_renderer log_level;
          if not (check_ocamlmerlin ()) then (
            Log.err (fun m -> m "ocamlmerlin not found in PATH");
            Log.err (fun m -> m "To fix this, run one of the following:");
            Log.err (fun m -> m "  1. eval $(opam env)  # If using opam");
            Log.err (fun m ->
                m "  2. opam install merlin  # If merlin is not installed");
            Stdlib.exit 1)
          else analyze_files ~exclude_patterns files)
      $ Fmt_cli.style_renderer () $ log_level $ exclude_flag $ files)

let () = Stdlib.exit (Cmd.eval cmd)
