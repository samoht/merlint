(** E400: Missing MLI Documentation *)

type payload = { module_name : string; file : string }
(** Payload for missing documentation issues *)

let check_mli_documentation_content ~module_name ~filename content =
  if String.trim content = "" then None
  else
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
      | [] -> None
      | line :: rest ->
          let trimmed = String.trim line in
          if trimmed = "" then check_first_non_empty rest
          else if starts_with "(**" trimmed then None
          else if starts_with "(*" trimmed then
            (* Regular comment - skip it and continue looking *)
            if ends_with "*)" trimmed then check_first_non_empty rest
            else check_first_non_empty (skip_comment rest)
          else
            Some
              (Issue.v
                 ~loc:(Location.in_file filename)
                 { module_name; file = filename })
    in
    check_first_non_empty lines

let check (ctx : Context.file) =
  let filename = Context.filename ctx in
  if not (File_kind.is_mli filename) then []
  else
    let module_name = Filename.basename filename |> Filename.remove_extension in
    match
      check_mli_documentation_content ~module_name ~filename
        (Context.content ctx)
    with
    | Some issue -> [ issue ]
    | None -> []

let pp ppf { module_name; file } =
  Fmt.pf ppf "Module %s (%s) is missing documentation comment" module_name file

let rule =
  Rule.v ~code:"E400" ~title:"Missing MLI Documentation" ~category:Documentation
    ~hint:
      "MLI files should start with a documentation comment (** ... *) that \
       describes the module's purpose and API. This helps users understand how \
       to use the module."
    ~examples:
      [ Example.bad Examples.E400.bad_mli; Example.good Examples.E400.good_mli ]
    ~pp (File check)
