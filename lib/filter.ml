(** Rule filter implementation for -r/--rules flag *)

type t = {
  enabled : string list option; (* None means all enabled *)
  disabled : string list;
}

let empty = { enabled = None; disabled = [] }

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
            (fun i -> Printf.sprintf "E%03d" (start_num + i))
        in
        Ok codes
      with Failure _ ->
        Error (Printf.sprintf "Invalid range format: %s" range_str))
  | _ -> Error (Printf.sprintf "Invalid range format: %s" range_str)

(** Parse a single rule specification *)
let parse_rule_spec spec =
  if String.contains spec '.' && String.contains spec '.' then
    (* It's a range *)
    parse_range spec
  else if String.starts_with ~prefix:"E" spec then
    (* Single error code *)
    Ok [ spec ]
  else Error (Printf.sprintf "Invalid rule specification: %s" spec)

(** Parse rules using the format: all-E110-E205 or E300+E305 or none *)
let parse rules_str =
  let rules_str = String.trim rules_str in
  if rules_str = "" then Ok empty
  else if rules_str = "all" then
    (* Special keyword to enable all rules *)
    Ok empty
  else if rules_str = "none" then
    (* Special keyword to disable all rules *)
    Ok { enabled = Some []; disabled = [] }
  else if String.starts_with ~prefix:"all-" rules_str then
    (* Format: all-E110-E205 - all rules except these *)
    let excluded = String.sub rules_str 4 (String.length rules_str - 4) in
    let parts = String.split_on_char '-' excluded in
    let rec parse_parts acc = function
      | [] -> Ok acc
      | part :: rest -> (
          match parse_rule_spec part with
          | Ok codes -> parse_parts (codes @ acc) rest
          | Error _ as err -> err)
    in
    match parse_parts [] parts with
    | Ok disabled -> Ok { enabled = None; disabled }
    | Error _ as err -> err
  else if
    String.contains rules_str '-'
    && not (String.starts_with ~prefix:"all-" rules_str)
  then
    (* Mixed format with exclusions: 300..399-E320 or E300+E305-E320 *)
    (* Split by operators while keeping track of the operators *)
    let rec tokenize str acc =
      if String.length str = 0 then List.rev acc
      else if String.starts_with ~prefix:"E" str then
        (* Find the end of this error code *)
        let rec find_end i =
          if i >= String.length str then i
          else match str.[i] with '+' | '-' -> i | _ -> find_end (i + 1)
        in
        let end_idx = find_end 1 in
        let token = String.sub str 0 end_idx in
        let rest = String.sub str end_idx (String.length str - end_idx) in
        tokenize rest (token :: acc)
      else if str.[0] = '+' || str.[0] = '-' then
        let op = String.make 1 str.[0] in
        let rest = String.sub str 1 (String.length str - 1) in
        tokenize rest (op :: acc)
      else
        (* Must be a range like 300..399 *)
        let rec find_end i =
          if i >= String.length str then i
          else match str.[i] with '+' | '-' -> i | _ -> find_end (i + 1)
        in
        let end_idx = find_end 0 in
        let token = String.sub str 0 end_idx in
        let rest = String.sub str end_idx (String.length str - end_idx) in
        tokenize rest (token :: acc)
    in
    let tokens = tokenize rules_str [] in
    let rec process_tokens enabled disabled = function
      | [] -> Ok { enabled = Some enabled; disabled }
      | [ spec ] -> (
          (* Last token, add to enabled by default *)
          match parse_rule_spec spec with
          | Ok codes -> Ok { enabled = Some (codes @ enabled); disabled }
          | Error _ as err -> err)
      | spec :: "+" :: rest -> (
          match parse_rule_spec spec with
          | Ok codes -> process_tokens (codes @ enabled) disabled rest
          | Error _ as err -> err)
      | spec :: "-" :: rest -> (
          match parse_rule_spec spec with
          | Ok codes ->
              (* First spec is added to enabled, rest goes to processing *)
              process_tokens (codes @ enabled) disabled ("-" :: rest)
          | Error _ as err -> err)
      | "-" :: spec :: rest -> (
          (* This spec should be disabled *)
          match parse_rule_spec spec with
          | Ok codes -> process_tokens enabled (codes @ disabled) rest
          | Error _ as err -> err)
      | _ :: rest -> process_tokens enabled disabled rest
    in
    process_tokens [] [] tokens
  else if String.contains rules_str '+' then
    (* Format: E300+E305 - only these rules *)
    let parts = String.split_on_char '+' rules_str in
    let rec parse_parts acc = function
      | [] -> Ok acc
      | part :: rest -> (
          match parse_rule_spec part with
          | Ok codes -> parse_parts (codes @ acc) rest
          | Error _ as err -> err)
    in
    match parse_parts [] parts with
    | Ok enabled -> Ok { enabled = Some enabled; disabled = [] }
    | Error _ as err -> err
  else
    (* Single rule or range *)
    match parse_rule_spec rules_str with
    | Ok codes -> Ok { enabled = Some codes; disabled = [] }
    | Error _ as err -> err

let is_enabled_by_code filter code =
  match filter.enabled with
  | None -> not (List.mem code filter.disabled)
  | Some enabled ->
      (* Check if code is in enabled list AND not in disabled list *)
      List.mem code enabled && not (List.mem code filter.disabled)
