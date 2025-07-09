open Cmdliner

let check_ocamlmerlin () =
  let cmd = "which ocamlmerlin > /dev/null 2>&1" in
  match Unix.system cmd with Unix.WEXITED 0 -> true | _ -> false

let find_files_in_dir ~suffix dir =
  let rec find_files acc path =
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
              then find_files acc full_path
              else acc
            else if Filename.check_suffix item suffix then full_path :: acc
            else acc
          with _ -> acc)
        acc items
    with _ -> acc
  in
  find_files [] dir

let expand_paths ~suffix paths =
  List.fold_left
    (fun acc path ->
      if Sys.file_exists path then
        if Sys.is_directory path then find_files_in_dir ~suffix path @ acc
        else if Filename.check_suffix path suffix then path :: acc
        else acc
      else (
        Printf.eprintf "Warning: %s does not exist\n" path;
        acc))
    [] paths
  |> List.rev

let find_all_project_files ~suffix () =
  let rec find_dune_root dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then Some dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else find_dune_root parent
  in
  match find_dune_root (Sys.getcwd ()) with
  | Some root -> find_files_in_dir ~suffix root
  | None -> find_files_in_dir ~suffix (Sys.getcwd ())

let analyze_with_merlin config file =
  match Merlint.Merlin_interface.analyze_file config file with
  | Ok violations -> violations
  | Error msg ->
      Printf.eprintf "Error analyzing %s: %s\n" file msg;
      []

let get_violation_location v =
  match v with
  | Merlint.Violation.Complexity_exceeded { location; _ }
  | Function_too_long { location; _ }
  | No_obj_magic { location }
  | Missing_value_doc { location; _ }
  | Bad_doc_style { location; _ }
  | Bad_variant_naming { location; _ }
  | Bad_module_naming { location; _ }
  | Bad_value_naming { location; _ }
  | Bad_type_naming { location; _ }
  | Catch_all_exception { location }
  | Use_str_module { location }
  | Deep_nesting { location; _ } ->
      Some location
  | _ -> None

let get_violation_file v =
  match v with
  | Merlint.Violation.Missing_mli_doc { file; _ }
  | Missing_standard_function { file; _ } ->
      Some file
  | _ -> None

let compare_violations a b =
  match (get_violation_file a, get_violation_file b) with
  | Some f1, Some f2 -> String.compare f1 f2
  | _ -> (
      match (get_violation_location a, get_violation_location b) with
      | Some l1, Some l2 ->
          let fc = String.compare l1.file l2.file in
          if fc <> 0 then fc else compare l1.line l2.line
      | _ -> 0)

let analyze_files files =
  let config = Merlint.Cyclomatic_complexity.default_config in

  (* Find all ML and MLI files *)
  let ml_files =
    if files = [] then find_all_project_files ~suffix:".ml" ()
    else expand_paths ~suffix:".ml" files
  in
  let mli_files =
    if files = [] then find_all_project_files ~suffix:".mli" ()
    else expand_paths ~suffix:".mli" files
  in

  (* Run complexity and style checks on ML files *)
  let ml_violations = List.concat_map (analyze_with_merlin config) ml_files in

  (* Run documentation checks on MLI files *)
  let doc_violations = Merlint.Doc_rules.check_mli_files mli_files in

  (* Sort and print violations *)
  let all_violations = ml_violations @ doc_violations in
  let sorted_violations = List.sort compare_violations all_violations in

  List.iter
    (fun v -> print_endline (Merlint.Violation.format v))
    sorted_violations;

  if sorted_violations <> [] then exit 1

let files =
  let doc =
    "OCaml source files or directories to analyze. If none specified, analyzes \
     all .ml and .mli files in the current dune project."
  in
  Arg.(value & pos_all string [] & info [] ~docv:"FILE|DIR" ~doc)

let cmd =
  let doc = "Analyze OCaml code for style violations" in
  let man =
    [
      `S Manpage.s_description;
      `P
        "$(tname) analyzes OCaml source files and reports violations of modern \
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
      const (fun files ->
          if not (check_ocamlmerlin ()) then (
            Printf.eprintf "Error: ocamlmerlin not found in PATH.\n\n";
            Printf.eprintf "To fix this, run one of the following:\n";
            Printf.eprintf "  1. eval $(opam env)  # If using opam\n";
            Printf.eprintf
              "  2. opam install merlin  # If merlin is not installed\n";
            Stdlib.exit 1)
          else analyze_files files)
      $ files)

let () = Stdlib.exit (Cmd.eval cmd)
