let check_mli_documentation filename =
  try
    let ic = open_in filename in
    let rec check_first_non_empty () =
      try
        let line = input_line ic in
        let trimmed = String.trim line in
        if trimmed = "" then check_first_non_empty ()
        else if String.length trimmed >= 3 && String.sub trimmed 0 3 = "(**"
        then None
        else
          let module_name =
            Filename.basename filename |> Filename.remove_extension
          in
          Some (Issue.Missing_mli_doc { module_name; file = filename })
      with End_of_file ->
        let module_name =
          Filename.basename filename |> Filename.remove_extension
        in
        Some (Issue.Missing_mli_doc { module_name; file = filename })
    in
    let result = check_first_non_empty () in
    close_in ic;
    result
  with _ -> None

let check_mli_files files =
  List.filter_map
    (fun file ->
      if Filename.check_suffix file ".mli" then check_mli_documentation file
      else None)
    files
