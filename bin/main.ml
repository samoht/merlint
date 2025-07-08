open Cmdliner

let check_ocamlmerlin () =
  let cmd = "which ocamlmerlin > /dev/null 2>&1" in
  match Unix.system cmd with
  | Unix.WEXITED 0 -> true
  | _ -> false

let find_ml_files_in_dir dir =
  let rec find_files acc path =
    try
      let items = Sys.readdir path in
      Array.fold_left (fun acc item ->
        let full_path = Filename.concat path item in
        try
          if Sys.is_directory full_path then
            if item <> "_build" && item <> "_opam" && String.length item > 0 && item.[0] <> '.' then
              find_files acc full_path
            else
              acc
          else if Filename.check_suffix item ".ml" then
            full_path :: acc
          else
            acc
        with _ -> acc
      ) acc items
    with _ -> acc
  in
  find_files [] dir

let expand_paths paths =
  List.fold_left (fun acc path ->
    if Sys.file_exists path then
      if Sys.is_directory path then
        find_ml_files_in_dir path @ acc
      else if Filename.check_suffix path ".ml" then
        path :: acc
      else
        acc
    else
      (Printf.eprintf "Warning: %s does not exist\n" path; acc)
  ) [] paths |> List.rev

let find_all_project_ml_files () =
  let rec find_dune_root dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then
      Some dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then None
      else find_dune_root parent
  in
  match find_dune_root (Sys.getcwd ()) with
  | Some root -> find_ml_files_in_dir root
  | None -> find_ml_files_in_dir (Sys.getcwd ())

let analyze_files config files =
  let total_violations = ref 0 in
  List.iter (fun file ->
    match Cyclomatic.Merlin_interface.analyze_file config file with
    | Ok violations ->
        List.iter (fun v ->
          print_endline (Cyclomatic.Cyclomatic_complexity.format_violation v);
          incr total_violations
        ) violations
    | Error msg ->
        Printf.eprintf "Error analyzing %s: %s\n" file msg
  ) files;
  if !total_violations > 0 then
    exit 1

let files =
  let doc = "OCaml source files or directories to analyze. If none specified, analyzes all .ml files in the current dune project." in
  Arg.(value & pos_all string [] & info [] ~docv:"FILE|DIR" ~doc)

let max_complexity =
  let doc = "Maximum allowed cyclomatic complexity" in
  Arg.(value & opt int 10 & info ["max-complexity"; "c"] ~docv:"N" ~doc)

let max_length =
  let doc = "Maximum allowed function length in lines" in
  Arg.(value & opt int 50 & info ["max-length"; "l"] ~docv:"N" ~doc)

let cmd =
  let doc = "Analyze OCaml code cyclomatic complexity" in
  let man = [
    `S Manpage.s_description;
    `P "$(tname) analyzes OCaml source files and reports functions that exceed \
        complexity or length thresholds.";
    `P "It uses Merlin to parse the OCaml AST and calculate cyclomatic complexity \
        based on control flow constructs.";
    `P "If no files or directories are specified, it analyzes all .ml files in the \
        current dune project (searching upward for dune-project).";
  ] in
  let info = Cmd.info "cyclomatic" ~version:"0.1.0" ~doc ~man in
  Cmd.v info
    Term.(const (fun complexity length files ->
      let config = Cyclomatic.Cyclomatic_complexity.{
        max_complexity = complexity;
        max_function_length = length;
      } in
      if not (check_ocamlmerlin ()) then begin
        Printf.eprintf "Error: ocamlmerlin not found in PATH.\n\n";
        Printf.eprintf "To fix this, run one of the following:\n";
        Printf.eprintf "  1. eval $(opam env)  # If using opam\n";
        Printf.eprintf "  2. opam install merlin  # If merlin is not installed\n";
        Stdlib.exit 1
      end else
        let files_to_analyze = 
          match files with
          | [] -> find_all_project_ml_files ()
          | paths -> expand_paths paths
        in
        if files_to_analyze = [] then
          Printf.eprintf "No OCaml files found to analyze.\n"
        else
          analyze_files config files_to_analyze
    ) $ max_complexity $ max_length $ files)

let () = Stdlib.exit (Cmd.eval cmd)