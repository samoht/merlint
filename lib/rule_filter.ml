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
  | "E335" -> Some Issue_type.Used_underscore_binding
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

(** Parse a range of error codes like "100..199" *)
let parse_range range_str =
  match String.split_on_char '.' range_str with
  | [ start; ""; ""; stop ] | [ start; ""; stop ] -> (
      try
        let start_num = int_of_string start in
        let stop_num = int_of_string stop in
        let codes =
          List.init
            (stop_num - start_num + 1)
            (fun i -> Fmt.str "E%03d" (start_num + i))
        in
        let issue_types = List.filter_map parse_error_code codes in
        Ok issue_types
      with _ -> Error (Fmt.str "Invalid range: %s" range_str))
  | _ ->
      Error
        (Fmt.str "Invalid range format: %s (expected: start..stop)" range_str)

(** Parse a single warning specifier like "E110" or "A" or "100..199" *)
let parse_single_spec spec =
  match spec with
  | "A" | "a" | "all" ->
      (* All warnings *)
      Ok Issue_type.all
  | s when String.contains s '.' ->
      (* Range specification *)
      parse_range s
  | code -> (
      match parse_error_code code with
      | Some issue_type -> Ok [ issue_type ]
      | None -> Error (Fmt.str "Unknown error code: %s" code))

(** Parse warning specification using simple format without quotes:
    - "all-E110-E205" - all rules except E110 and E205
    - "E300+E305" - only E300 and E305
    - "all-100..199" - all except error codes 100-199 *)
let parse spec =
  (* First extract positive selections (if any) *)
  let parts = String.split_on_char '+' spec in
  let base_spec, additions =
    match parts with [] -> ("", []) | base :: rest -> (base, rest)
  in

  (* Parse base spec and exclusions *)
  let tokens =
    if base_spec = "" && additions <> [] then
      (* Only additions, no base *)
      List.map (fun s -> s) additions
    else if String.starts_with ~prefix:"all" base_spec then
      (* all-E110-E205 format *)
      let exclusions = String.split_on_char '-' base_spec |> List.tl in
      ("all" :: List.map (fun s -> "-" ^ s) exclusions) @ additions
    else if base_spec <> "" then
      (* Single spec or range *)
      base_spec :: additions
    else []
  in

  let tokens = List.map String.trim tokens |> List.filter (fun s -> s <> "") in

  let rec process tokens filter =
    match tokens with
    | [] -> Ok filter
    | token :: rest when String.length token > 0 -> (
        let is_disable = String.length token > 0 && String.get token 0 = '-' in
        let code =
          if is_disable then String.sub token 1 (String.length token - 1)
          else token
        in
        match parse_single_spec code with
        | Ok types ->
            let filter =
              if is_disable then
                { filter with disabled = types @ filter.disabled }
              else
                match types with
                | t when t = Issue_type.all ->
                    (* Special case: "all" enables all *)
                    { filter with enabled = None }
                | _ -> (
                    match filter.enabled with
                    | None -> { filter with enabled = Some types }
                    | Some existing ->
                        { filter with enabled = Some (types @ existing) })
            in
            process rest filter
        | Error e -> Error e)
    | "" :: rest -> process rest filter (* Skip empty tokens *)
    | _ -> Error "Invalid rule specification"
  in

  process tokens empty

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
