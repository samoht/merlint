(** E400: Missing MLI Documentation *)

type payload = { module_name : string; file : string }
(** Payload for missing documentation issues *)

let check_mli_documentation_content ~module_name ~filename content =
  let lines = String.split_on_char '\n' content in
  let starts_with prefix s =
    String.length s >= String.length prefix
    && String.sub s 0 (String.length prefix) = prefix
  in
  let ends_with suffix s =
    String.length s >= String.length suffix
    && String.sub s
         (String.length s - String.length suffix)
         (String.length suffix)
       = suffix
  in
  (* Skip regular comments (including multi-line license comments) *)
  let rec skip_comment = function
    | [] -> []
    | line :: rest ->
        let trimmed = String.trim line in
        if ends_with "*)" trimmed then rest else skip_comment rest
  in
  let rec check_first_non_empty = function
    | [] ->
        (* Empty file - missing documentation *)
        Some (Issue.v { module_name; file = filename })
    | line :: rest ->
        let trimmed = String.trim line in
        if trimmed = "" then check_first_non_empty rest
        else if starts_with "(**" trimmed then None
        else if starts_with "(*" trimmed then
          (* Regular comment - skip it and continue looking *)
          if ends_with "*)" trimmed then check_first_non_empty rest
          else check_first_non_empty (skip_comment rest)
        else Some (Issue.v { module_name; file = filename })
  in
  check_first_non_empty lines

let check (ctx : Context.project) =
  File.process_ocaml_files ctx (fun filename content ->
      if Filename.check_suffix filename ".mli" then
        let module_name =
          Filename.basename filename |> Filename.remove_extension
        in
        (* Skip test modules - they don't need comprehensive documentation *)
        if String.starts_with ~prefix:"test_" module_name then []
        else
          match
            check_mli_documentation_content ~module_name ~filename content
          with
          | Some issue -> [ issue ]
          | None -> []
      else [])

let pp ppf { module_name; file } =
  Fmt.pf ppf "Module %s (%s) is missing documentation comment" module_name file

let rule =
  Rule.v ~code:"E400" ~title:"Missing MLI Documentation" ~category:Documentation
    ~hint:
      "MLI files should start with a documentation comment (** ... *) that \
       describes the module's purpose and API. This helps users understand how \
       to use the module. Test modules (test_*) are excluded from this check."
    ~examples:
      [ Example.bad Examples.E400.bad_mli; Example.good Examples.E400.good_mli ]
    ~pp (Project check)
