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
            (fun i -> Fmt.str "E%03d" (start_num + i))
        in
        Ok codes
      with Failure _ -> Error (Fmt.str "Invalid range format: %s" range_str))
  | _ -> Error (Fmt.str "Invalid range format: %s" range_str)

(** Parse a single rule specification *)
let parse_rule_spec spec =
  if String.contains spec '.' && String.contains spec '.' then
    (* It's a range *)
    parse_range spec
  else if String.starts_with ~prefix:"E" spec then
    (* Single error code *)
    Ok [ spec ]
  else Error (Fmt.str "Invalid rule specification: %s" spec)

(** Find the next operator (+/-) position in a string *)
let find_next_operator str start =
  let rec find i =
    if i >= String.length str then i
    else match str.[i] with '+' | '-' -> i | _ -> find (i + 1)
  in
  find start

(** Extract the next token from a rule string *)
let extract_token str =
  if String.length str = 0 then None
  else if str.[0] = '+' || str.[0] = '-' then
    Some (String.make 1 str.[0], String.sub str 1 (String.length str - 1))
  else
    let end_idx = find_next_operator str 0 in
    let token = String.sub str 0 end_idx in
    let rest = String.sub str end_idx (String.length str - end_idx) in
    Some (token, rest)

(** Tokenize a rule string into tokens *)
let rec tokenize str acc =
  match extract_token str with
  | None -> List.rev acc
  | Some (token, rest) -> tokenize rest (token :: acc)

(** Process a list of tokens into enabled/disabled rules *)
let rec process_tokens enabled disabled = function
  | [] -> Ok { enabled = Some enabled; disabled }
  | [ spec ] ->
      (* Last token, add to enabled by default *)
      parse_rule_spec spec
      |> Result.map (fun codes ->
             { enabled = Some (codes @ enabled); disabled })
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

(** Parse exclusion rules (all-E110-E205) *)
let parse_exclusions excluded =
  let parts = String.split_on_char '-' excluded in
  let rec parse_parts acc = function
    | [] -> Ok acc
    | part :: rest -> (
        match parse_rule_spec part with
        | Ok codes -> parse_parts (codes @ acc) rest
        | Error _ as err -> err)
  in
  parse_parts [] parts
  |> Result.map (fun disabled -> { enabled = None; disabled })

(** Parse inclusion rules (E300+E305) *)
let parse_inclusions rules_str =
  let parts = String.split_on_char '+' rules_str in
  let rec parse_parts acc = function
    | [] -> Ok acc
    | part :: rest -> (
        match parse_rule_spec part with
        | Ok codes -> parse_parts (codes @ acc) rest
        | Error _ as err -> err)
  in
  parse_parts [] parts
  |> Result.map (fun enabled -> { enabled = Some enabled; disabled = [] })

(** Parse rules using the format: all-E110-E205 or E300+E305 or none *)
let parse rules_str =
  let rules_str = String.trim rules_str in
  match rules_str with
  | "" -> Ok empty
  | "all" -> Ok empty
  | "none" -> Ok { enabled = Some []; disabled = [] }
  | _ when String.starts_with ~prefix:"all-" rules_str ->
      (* Format: all-E110-E205 - all rules except these *)
      let excluded = String.sub rules_str 4 (String.length rules_str - 4) in
      parse_exclusions excluded
  | _
    when String.contains rules_str '-'
         && not (String.starts_with ~prefix:"all-" rules_str) ->
      (* Mixed format with exclusions: 300..399-E320 or E300+E305-E320 *)
      let tokens = tokenize rules_str [] in
      process_tokens [] [] tokens
  | _ when String.contains rules_str '+' ->
      (* Format: E300+E305 - only these rules *)
      parse_inclusions rules_str
  | _ ->
      (* Single rule or range *)
      parse_rule_spec rules_str
      |> Result.map (fun codes -> { enabled = Some codes; disabled = [] })

let is_enabled_by_code filter code =
  match filter.enabled with
  | None -> not (List.mem code filter.disabled)
  | Some enabled ->
      (* Check if code is in enabled list AND not in disabled list *)
      List.mem code enabled && not (List.mem code filter.disabled)
