open Cmdliner

let logs_src = Logs.Src.create "merlint" ~doc:"Merlint OCaml linter"
module Log = (val Logs.src_log logs_src : Logs.LOG)

let setup_log ?style_renderer log_level =
  (* Setup logging with colors *)
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level log_level;
  Logs.set_reporter
    (Logs_fmt.reporter ~dst:Format.err_formatter ~app:Fmt.stdout ())

let check_ocamlmerlin () =
  let cmd = "which ocamlmerlin > /dev/null 2>&1" in
  match Unix.system cmd with Unix.WEXITED 0 -> true | _ -> false

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
        Printf.eprintf "Warning: %s does not exist\n" path;
        acc))
    [] paths
  |> List.rev

let get_all_project_files ~suffix () =
  let rec find_dune_root dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then Some dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else find_dune_root parent
  in
  match find_dune_root (Sys.getcwd ()) with
  | Some root -> get_files_in_dir ~suffix root
  | None -> get_files_in_dir ~suffix (Sys.getcwd ())



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


let run_analysis project_root filtered_files =
  let rules_config = Merlint.Rules.default_config project_root in
  Log.info (fun m -> m "Starting visual analysis on %d files" (List.length filtered_files));
  let category_reports =
    Merlint.Rules.analyze_project rules_config filtered_files
  in

  Printf.printf "Running merlint analysis...\n\n";
  Printf.printf "Analyzing %d files\n\n" (List.length filtered_files);

  let all_reports =
    List.fold_left
      (fun acc (category_name, reports) ->
        let total_issues =
          List.fold_left
            (fun acc report -> acc + List.length report.Merlint.Report.issues)
            0 reports
        in
        let category_passed =
          List.for_all (fun report -> report.Merlint.Report.passed) reports
        in

        Printf.printf "%s %s (%d total issues)\n"
          (Merlint.Report.print_color category_passed
             (Merlint.Report.print_status category_passed))
          category_name total_issues;

        (* Only show detailed reports if there are issues *)
        if total_issues > 0 then
          List.iter Merlint.Report.print_detailed reports;
        reports @ acc)
      [] category_reports
  in

  Merlint.Report.print_summary all_reports;

  let all_issues = Merlint.Report.get_all_issues all_reports in
  if all_issues <> [] then exit 1

let ensure_project_built project_root =
  match Merlint.Dune.ensure_project_built project_root with
  | Ok () -> ()
  | Error msg -> 
      Printf.eprintf "Warning: %s\n" msg;
      Printf.eprintf "Function type analysis may not work properly.\n";
      Printf.eprintf "Continuing with analysis...\n"

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
      get_all_project_files ~suffix:".ml" ()
      @ get_all_project_files ~suffix:".mli" ()
    else expand_paths ~suffix:".ml" files @ expand_paths ~suffix:".mli" files
  in

  Log.debug (fun m -> m "Found %d total files before filtering" (List.length all_files));

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

  Log.info (fun m -> m "Analyzing %d files after exclusions" (List.length filtered_files));
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
            Log.err (fun m -> m "  2. opam install merlin  # If merlin is not installed");
            Stdlib.exit 1)
          else analyze_files ~exclude_patterns files)
      $ Fmt_cli.style_renderer () $ log_level $ exclude_flag $ files)

let () = Stdlib.exit (Cmd.eval cmd)
