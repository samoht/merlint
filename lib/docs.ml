(** Documentation style analysis and validation *)

type style_issue =
  | Missing_period
  | Bad_function_format
  | Bad_value_format
  | Bad_operator_format
  | Wrong_arg_count of { expected : int; found : int }
  | Redundant_phrase of string

(* Top-level arrow at position [i] (not inside parens). *)

(** Count required and total arguments in a signature string. e.g., "?foo:int ->
    string -> int -> bool" has 2 required, 3 total. Returns (required_count,
    total_count). Ignores arrows inside parentheses (function-typed arguments).
*)
let is_top_level_arrow signature i depth =
  depth = 0
  && i + 1 < String.length signature
  && signature.[i] = '-'
  && signature.[i + 1] = '>'

let count_args signature =
  let len = String.length signature in
  let rec scan acc_total acc_optional depth i optional_in_arg =
    if i >= len then (acc_optional, acc_total)
    else if is_top_level_arrow signature i depth then
      let new_optional =
        if optional_in_arg then acc_optional + 1 else acc_optional
      in
      scan (acc_total + 1) new_optional depth (i + 2) false
    else
      match signature.[i] with
      | '(' -> scan acc_total acc_optional (depth + 1) (i + 1) optional_in_arg
      | ')' ->
          scan acc_total acc_optional
            (max 0 (depth - 1))
            (i + 1) optional_in_arg
      | '?' when depth = 0 -> scan acc_total acc_optional depth (i + 1) true
      | _ -> scan acc_total acc_optional depth (i + 1) optional_in_arg
  in
  let optional_count, total_count = scan 0 0 0 0 false in
  let required_count = max 0 (total_count - optional_count) in
  (required_count, total_count)

(** Count arguments in a doc pattern [name arg1 arg2 ...] *)
let count_doc_args doc_content =
  (* doc_content is the content inside [...], e.g., "name arg1 arg2" *)
  let parts =
    String.split_on_char ' ' doc_content
    |> List.filter (fun s -> String.trim s <> "")
  in
  (* First part is the name, rest are args *)
  max 0 (List.length parts - 1)

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
  if found_args > 0 then begin
    let min_args, max_args = count_args signature in
    if found_args < min_args then
      issues :=
        Wrong_arg_count { expected = min_args; found = found_args } :: !issues
    else if found_args > max_args then
      issues :=
        Wrong_arg_count { expected = max_args; found = found_args } :: !issues
  end

let check_bracket_format ~name ~signature ~is_operator ~doc issues =
  let bracket_pattern =
    Re.compile
      (Re.seq
         [
           Re.str "[";
           Re.group (Re.rep1 (Re.diff Re.any (Re.char ']')));
           Re.str "]";
         ])
  in
  match Re.exec_opt bracket_pattern doc with
  | Some groups ->
      let bracket_content = Re.Group.get groups 1 in
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
     and has the right number of arguments. Otherwise, accept any doc format. *)
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

  (* No bracket format - that's fine, accept as valid *)

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
  let bracket_pattern =
    Re.compile
      (Re.seq
         [
           Re.str "[";
           Re.group (Re.rep1 (Re.diff Re.any (Re.set " ]")));
           Re.str "]";
         ])
  in
  match Re.exec_opt bracket_pattern doc with
  | Some groups ->
      let doc_name = Re.Group.get groups 1 in
      if doc_name <> name then issues := Bad_value_format :: !issues
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
  | Wrong_arg_count { expected; found } ->
      Fmt.str "has %d args in doc but function takes %d required args" found
        expected
  | Redundant_phrase phrase -> Fmt.str "avoid redundant phrase '%s'" phrase

let pp_style_issue ppf issue = Fmt.string ppf (style_issue_message issue)
let equal_style_issue = ( = )
