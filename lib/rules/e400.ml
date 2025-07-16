(** E400: Missing MLI Documentation *)

let check_mli_documentation_content ~module_name ~filename content =
  let lines = String.split_on_char '\n' content in
  let rec check_first_non_empty = function
    | [] ->
        (* Empty file - missing documentation *)
        Some (Issue.missing_mli_doc ~module_name ~file:filename)
    | line :: rest ->
        let trimmed = String.trim line in
        if trimmed = "" then check_first_non_empty rest
        else if String.length trimmed >= 3 && String.sub trimmed 0 3 = "(**"
        then None
        else Some (Issue.missing_mli_doc ~module_name ~file:filename)
  in
  check_first_non_empty lines

let check ctx =
  Traverse.process_ocaml_files ctx (fun filename content ->
      if Filename.check_suffix filename ".mli" then
        let module_name =
          Filename.basename filename |> Filename.remove_extension
        in
        match
          check_mli_documentation_content ~module_name ~filename content
        with
        | Some issue -> [ issue ]
        | None -> []
      else [])
