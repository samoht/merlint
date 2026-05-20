(** Documentation style analysis and validation *)

type style_issue =
  | Missing_period
  | Bad_function_format
  | Bad_value_format
  | Bad_operator_format
  | Wrong_arg_count of { min : int; max : int; found : int }
  | Redundant_phrase of string

let is_top_level_arrow signature i depth =
  depth = 0
  && i + 1 < String.length signature
  && signature.[i] = '-'
  && signature.[i + 1] = '>'

let is_optional_arg arg =
  match String.trim arg with "" -> false | s -> s.[0] = '?'

let count_signature_args signature =
  let len = String.length signature in
  let rec scan args depth start i =
    if i >= len then List.rev args
    else if is_top_level_arrow signature i depth then
      let arg = String.sub signature start (i - start) in
      scan (arg :: args) depth (i + 2) (i + 2)
    else
      match signature.[i] with
      | '(' -> scan args (depth + 1) start (i + 1)
      | ')' -> scan args (max 0 (depth - 1)) start (i + 1)
      | _ -> scan args depth start (i + 1)
  in
  let args = scan [] 0 0 0 in
  let max = List.length args in
  let optional = List.filter is_optional_arg args |> List.length in
  (max - optional, max)

let count_doc_args bracket_content =
  String.split_on_char ' ' bracket_content
  |> List.filter (fun s -> String.trim s <> "")
  |> List.length
  |> fun n -> max 0 (n - 1)

let initial_bracket_content doc =
  let doc = String.trim doc in
  if String.length doc = 0 || doc.[0] <> '[' then None
  else
    match String.index_from_opt doc 1 ']' with
    | None -> None
    | Some stop -> Some (String.sub doc 1 (stop - 1))

let is_value_name s =
  let is_ident_char = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'' -> true
    | _ -> false
  in
  String.length s > 0
  &&
  match s.[0] with
  | 'a' .. 'z' | '_' -> String.for_all is_ident_char s
  | _ -> false

let check_operator_bracket ~name ~doc issues =
  let op_prefix =
    if String.length name > 0 && name.[0] = '.' then
      let stop =
        match String.index_opt name '{' with
        | Some i -> i
        | None -> String.length name
      in
      String.sub name 0 stop
    else name
  in
  let infix_pattern =
    Re.compile
      (Re.seq [ Re.str "["; Re.rep1 Re.alnum; Re.space; Re.str op_prefix ])
  in
  if not (Re.execp infix_pattern doc) then
    issues := Bad_operator_format :: !issues

let check_function_bracket ~name ~signature ~bracket_content issues =
  let parts =
    String.split_on_char ' ' bracket_content
    |> List.filter (fun s -> String.trim s <> "")
  in
  let doc_name = if List.length parts > 0 then List.hd parts else "" in
  if doc_name <> name then issues := Bad_function_format :: !issues;
  let found_args = count_doc_args bracket_content in
  if found_args > 0 then
    let min_args, max_args = count_signature_args signature in
    if found_args < min_args || found_args > max_args then
      issues :=
        Wrong_arg_count { min = min_args; max = max_args; found = found_args }
        :: !issues

let check_bracket_format ~name ~signature ~is_operator ~doc issues =
  match initial_bracket_content doc with
  | Some bracket_content ->
      if is_operator then check_operator_bracket ~name ~doc issues
      else check_function_bracket ~name ~signature ~bracket_content issues
  | None -> ()

let check_ends_with_period ~doc issues =
  let trimmed = String.trim doc in
  let has_list_markers =
    Re.execp (Re.compile (Re.str "- ")) doc
    || Re.execp (Re.compile (Re.str "* ")) doc
    || Re.execp (Re.compile (Re.str "+ ")) doc
  in
  if
    String.length trimmed > 0
    && (not (String.ends_with ~suffix:"." trimmed))
    && (not (String.ends_with ~suffix:"]}" trimmed))
    && not (has_list_markers && String.ends_with ~suffix:")" trimmed)
  then issues := Missing_period :: !issues

let check_function_doc ~name ~signature ~doc =
  (* If doc uses [x ...] format, verify x matches the function name
     being documented and, when it mentions arguments, covers all mandatory
     arguments without listing impossible arguments. Otherwise, accept any doc
     format. *)
  let issues = ref [] in

  (* Check if this is an operator *)
  let operator_keywords =
    [ "mod"; "land"; "lor"; "lxor"; "lsl"; "lsr"; "asr"; "or"; "and" ]
  in
  let is_operator =
    List.mem name operator_keywords
    || String.length name > 0
       && not
            (match name.[0] with
            | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
            | _ -> false)
  in

  (* Extract the content inside [...] if present *)
  check_bracket_format ~name ~signature ~is_operator ~doc issues;

  (* Check for redundant phrases *)
  let lower = String.lowercase_ascii doc in
  if
    String.starts_with ~prefix:"this function" lower
    || String.starts_with ~prefix:"this method" lower
  then issues := Redundant_phrase "This function" :: !issues;

  (* Check ends with period (but not if it ends with a code block ]} or if it's a list ending with ) *)
  check_ends_with_period ~doc issues;

  !issues

let check_type_doc ~doc =
  (* Type docs should be brief and end with period *)
  let issues = ref [] in
  check_ends_with_period ~doc issues;
  let lower = String.lowercase_ascii doc in
  if String.starts_with ~prefix:"this type" lower then
    issues := Redundant_phrase "This type" :: !issues;

  !issues

let check_value_bracket ~name ~doc issues =
  match initial_bracket_content doc with
  | Some bracket_content ->
      let doc_name =
        match String.index_opt bracket_content ' ' with
        | None -> bracket_content
        | Some stop -> String.sub bracket_content 0 stop
      in
      if is_value_name doc_name && doc_name <> name then
        issues := Bad_value_format :: !issues
  | None -> ()

let check_value_doc ~name ~doc =
  (* If doc uses [x] format, verify x matches the value name.
     Otherwise, accept any doc format. *)
  let issues = ref [] in
  check_value_bracket ~name ~doc issues;
  check_ends_with_period ~doc issues;
  let lower = String.lowercase_ascii doc in
  if
    String.starts_with ~prefix:"this value" lower
    || String.starts_with ~prefix:"this variable" lower
  then issues := Redundant_phrase "This value" :: !issues;

  !issues

let style_issue_message = function
  | Missing_period -> "should end with a period"
  | Bad_function_format -> "uses [name] format but name doesn't match"
  | Bad_value_format -> "uses [name] format but name doesn't match"
  | Bad_operator_format ->
      "should use '[x op y] description.' format for operators"
  | Wrong_arg_count { min; max; found } ->
      if found < min then
        Fmt.str
          "has %d args in doc but function takes at least %d mandatory args"
          found min
      else
        Fmt.str "has %d args in doc but function takes at most %d args" found
          max
  | Redundant_phrase phrase -> Fmt.str "avoid redundant phrase '%s'" phrase

let pp_style_issue ppf issue = Fmt.string ppf (style_issue_message issue)
let equal_style_issue = ( = )
