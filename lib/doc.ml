(** Legacy documentation module - all checks have been moved to rules/e400.ml *)

(** Legacy function for unit tests - exposed for testing *)
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

let check_mli_files files = E400.check files
