(** Rule filter implementation for -r/--rules flag *)

type t = {
  enabled : Issue_type.t list option; (* None means all enabled *)
  disabled : Issue_type.t list;
}

let empty = { enabled = None; disabled = [] }

(** Parse error code to issue type *)
let parse_error_code code =
  match code with
  | "E001" -> Some Issue_type.Complexity
  | "E005" -> Some Issue_type.Function_length
  | "E010" -> Some Issue_type.Deep_nesting
  | "E100" -> Some Issue_type.Obj_magic
  | "E105" -> Some Issue_type.Catch_all_exception
  | "E110" -> Some Issue_type.Silenced_warning
  | "E200" -> Some Issue_type.Str_module
  | "E205" -> Some Issue_type.Printf_module
  | "E300" -> Some Issue_type.Variant_naming
  | "E305" -> Some Issue_type.Module_naming
  | "E310" -> Some Issue_type.Value_naming
  | "E315" -> Some Issue_type.Type_naming
  | "E320" -> Some Issue_type.Long_identifier
  | "E325" -> Some Issue_type.Function_naming
  | "E330" -> Some Issue_type.Redundant_module_name
  | "E400" -> Some Issue_type.Missing_mli_doc
  | "E405" -> Some Issue_type.Missing_value_doc
  | "E410" -> Some Issue_type.Bad_doc_style
  | "E415" -> Some Issue_type.Missing_standard_function
  | "E500" -> Some Issue_type.Missing_ocamlformat_file
  | "E505" -> Some Issue_type.Missing_mli_file
  | "E600" -> Some Issue_type.Test_exports_module
  | "E605" -> Some Issue_type.Missing_test_file
  | "E610" -> Some Issue_type.Test_without_library
  | "E615" -> Some Issue_type.Test_suite_not_included
  | _ -> None

(** Parse a single warning specifier like "E110" or "A" *)
let parse_single_spec spec =
  match spec with
  | "A" | "a" ->
      (* All warnings *)
      Ok Issue_type.all
  | code -> (
      match parse_error_code code with
      | Some issue_type -> Ok [ issue_type ]
      | None -> Error (Fmt.str "Unknown error code: %s" code))

(** Parse warning specification like "A-E110-E205" *)
let parse spec =
  let parts = String.split_on_char '-' spec in
  let rec process parts filter =
    match parts with
    | [] -> Ok filter
    | "" :: rest -> process rest filter (* Skip empty parts *)
    | "+" :: code :: rest when code <> "" -> (
        (* Enable warnings *)
        match parse_single_spec code with
        | Ok types ->
            let filter =
              match filter.enabled with
              | None -> { filter with enabled = Some types }
              | Some existing ->
                  { filter with enabled = Some (types @ existing) }
            in
            process rest filter
        | Error e -> Error e)
    | code :: rest when code <> "" -> (
        (* Enable warnings *)
        match parse_single_spec code with
        | Ok types ->
            let filter =
              match filter.enabled with
              | None -> { filter with enabled = Some types }
              | Some existing ->
                  { filter with enabled = Some (types @ existing) }
            in
            process rest filter
        | Error e -> Error e)
    | _ -> Error "Invalid warning specification"
  in

  (* Handle different formats *)
  match parts with
  | [] -> Ok empty
  | first :: rest when first = "A" || first = "a" ->
      (* Start with all enabled, then process exclusions *)
      let rec process_exclusions parts filter =
        match parts with
        | [] -> Ok filter
        | code :: rest -> (
            match parse_single_spec code with
            | Ok types ->
                process_exclusions rest
                  { filter with disabled = types @ filter.disabled }
            | Error e -> Error e)
      in
      process_exclusions rest { enabled = None; disabled = [] }
  | _ -> process parts empty

(** Check if an issue type is enabled *)
let is_enabled filter issue_type =
  let is_disabled = List.mem issue_type filter.disabled in
  if is_disabled then false
  else
    match filter.enabled with
    | None -> true (* All enabled by default *)
    | Some enabled -> List.mem issue_type enabled

(** Filter a list of issues *)
let filter_issues filter issues =
  List.filter (fun issue -> is_enabled filter (Issue.get_type issue)) issues
