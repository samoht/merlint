(** E400: Missing MLI Documentation *)

let check_mli_documentation_content ~module_name ~filename content =
  let lines = String.split_on_char '\n' content in
  let rec check_first_non_empty = function
    | [] ->
        (* Empty file - missing documentation *)
        Some (Issue.Missing_mli_doc { module_name; file = filename })
    | line :: rest ->
        let trimmed = String.trim line in
        if trimmed = "" then check_first_non_empty rest
        else if String.length trimmed >= 3 && String.sub trimmed 0 3 = "(**"
        then None
        else Some (Issue.Missing_mli_doc { module_name; file = filename })
  in
  check_first_non_empty lines

let check_mli_documentation filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    let module_name = Filename.basename filename |> Filename.remove_extension in
    check_mli_documentation_content ~module_name ~filename content
  with Sys_error _ -> None

let check files =
  List.filter_map
    (fun file ->
      if Filename.check_suffix file ".mli" then check_mli_documentation file
      else None)
    files
