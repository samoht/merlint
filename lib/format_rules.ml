let check_ocamlformat_exists project_root =
  let ocamlformat_path = Filename.concat project_root ".ocamlformat" in
  if not (Sys.file_exists ocamlformat_path) then
    Some
      (Issue.Missing_ocamlformat_file
         { location = { file = project_root; line = 1; col = 1 } })
  else None

let check_ml_files_have_mli_from_files files =
  let issues = ref [] in
  List.iter
    (fun ml_file ->
      if String.ends_with ~suffix:".ml" ml_file then
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

let check_ml_files_have_mli project_root =
  let issues = ref [] in
  let rec scan_directory dir =
    try
      let entries = Sys.readdir dir in
      Array.iter
        (fun entry ->
          let full_path = Filename.concat dir entry in
          if
            Sys.is_directory full_path
            && (not (String.starts_with ~prefix:"." entry))
            && not (String.starts_with ~prefix:"_" entry)
          then scan_directory full_path
          else if String.ends_with ~suffix:".ml" entry then
            let base_name = Filename.remove_extension entry in
            let mli_path = Filename.concat dir (base_name ^ ".mli") in
            if not (Sys.file_exists mli_path) then
              issues :=
                Issue.Missing_mli_file
                  {
                    ml_file = full_path;
                    expected_mli = mli_path;
                    location = { file = full_path; line = 1; col = 1 };
                  }
                :: !issues)
        entries
    with Sys_error _ -> ()
  in
  scan_directory project_root;
  !issues

let check project_root =
  let format_issues =
    match check_ocamlformat_exists project_root with
    | Some issue -> [ issue ]
    | None -> []
  in
  let mli_issues = check_ml_files_have_mli project_root in
  format_issues @ mli_issues

let check_with_files project_root files =
  let format_issues =
    match check_ocamlformat_exists project_root with
    | Some issue -> [ issue ]
    | None -> []
  in
  let mli_issues = check_ml_files_have_mli_from_files files in
  format_issues @ mli_issues
