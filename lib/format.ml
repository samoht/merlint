let check_ocamlformat_exists project_root =
  let ocamlformat_path = Filename.concat project_root ".ocamlformat" in
  if not (Sys.file_exists ocamlformat_path) then
    Some
      (Issue.Missing_ocamlformat_file
         { location = { file = project_root; line = 1; col = 1 } })
  else None

let check_mli_for_files project_root files =
  let issues = ref [] in
  List.iter
    (fun ml_file ->
      if String.ends_with ~suffix:".ml" ml_file then
        (* Only check for .mli files for library modules, not executables *)
        if not (Dune.is_executable project_root ml_file) then
          let base_name = Filename.remove_extension ml_file in
          let mli_path = base_name ^ ".mli" in
          if not (Sys.file_exists mli_path) then
            issues :=
              Issue.Missing_mli_file
                {
                  ml_file;
                  expected_mli = mli_path;
                  location = { file = ml_file; line = 1; col = 1 };
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
