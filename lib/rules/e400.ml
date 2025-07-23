(** E400: Missing MLI Documentation *)

type payload = { module_name : string; file : string }
(** Payload for missing documentation issues *)

let check_mli_documentation_content ~module_name ~filename content =
  let lines = String.split_on_char '\n' content in
  let rec check_first_non_empty = function
    | [] ->
        (* Empty file - missing documentation *)
        Some (Issue.v { module_name; file = filename })
    | line :: rest ->
        let trimmed = String.trim line in
        if trimmed = "" then check_first_non_empty rest
        else if String.length trimmed >= 3 && String.sub trimmed 0 3 = "(**"
        then None
        else Some (Issue.v { module_name; file = filename })
  in
  check_first_non_empty lines

let check (ctx : Context.project) =
  File.process_ocaml_files ctx (fun filename content ->
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
    ~pp (Project check)
