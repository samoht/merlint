let check_ocamlformat_exists project_root =
  let ocamlformat_path = Filename.concat project_root ".ocamlformat" in
  if not (Sys.file_exists ocamlformat_path) then
    Some
      (Issue.Missing_ocamlformat_file
         {
           location =
             Location.create ~file:project_root ~start_line:1 ~start_col:1
               ~end_line:1 ~end_col:1;
         })
  else None

let check_mli_for_files project_root files =
  (* Get executable info once for all files *)
  let executable_modules = Dune.get_executable_info project_root in
  let is_executable_module ml_file =
    let module_name = Filename.basename (Filename.remove_extension ml_file) in
    let module_name_capitalized = String.capitalize_ascii module_name in
    let is_exe = List.mem module_name_capitalized executable_modules in
    if is_exe then
      Logs.debug (fun m ->
          m "File %s is executable (module %s)" ml_file module_name_capitalized);
    is_exe
  in

  let issues = ref [] in
  List.iter
    (fun ml_file ->
      if String.ends_with ~suffix:".ml" ml_file then
        (* Only check for .mli files for library modules, not executables *)
        if not (is_executable_module ml_file) then
          let base_name = Filename.remove_extension ml_file in
          let mli_path = base_name ^ ".mli" in
          if not (Sys.file_exists mli_path) then
            issues :=
              Issue.Missing_mli_file
                {
                  ml_file;
                  expected_mli = mli_path;
                  location =
                    Location.create ~file:ml_file ~start_line:1 ~start_col:1
                      ~end_line:1 ~end_col:1;
                }
              :: !issues)
    files;
  !issues

let check project_root files =
  let format_issues =
    match check_ocamlformat_exists project_root with
    | Some issue -> [ issue ]
    | None -> []
  in
  let mli_issues = check_mli_for_files project_root files in
  format_issues @ mli_issues
