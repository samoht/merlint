(** E310: Value Naming Convention *)

type payload = { value_name : string; expected : string }
(** Payload for bad value naming *)

(** Allow trailing uppercase suffixes in snake_case names. A single letter (e.g.
    [_A], [_B]) is always allowed; multi-letter uppercase suffixes are accepted
    only when the suffix matches a name from [allowed_words] (e.g.
    [answer_certificate_RSA] when [RSA] is in [allowed_words]). *)
let valid_snake_with_suffix ~allowed name =
  let len = String.length name in
  if len < 3 then false
  else
    match String.rindex_opt name '_' with
    | None -> false
    | Some i when i >= len - 1 -> false
    | Some i ->
        let prefix = String.sub name 0 i in
        let suffix = String.sub name (i + 1) (len - i - 1) in
        let prefix_ok = prefix = String.lowercase_ascii prefix in
        let all_upper = suffix = String.uppercase_ascii suffix in
        prefix_ok && all_upper
        && (String.length suffix = 1 || List.mem suffix allowed)

let check_value_name ~allowed name =
  (* Skip names starting with uppercase: these are first-class module bindings
     like (module M) which must be uppercase in OCaml *)
  if name <> "" && name.[0] >= 'A' && name.[0] <= 'Z' then
    None
    (* Whole-name allowlist: spec-mandated identifiers (RFC ASN.1 field
     names, IANA registry entries) keep their canonical mixed case. *)
  else if List.mem name allowed then None
  else
    let expected = Naming.to_lowercase_snake_case name in
    if name <> expected && name <> String.lowercase_ascii name then
      if valid_snake_with_suffix ~allowed name then None else Some expected
    else None

let check (ctx : Context.file) =
  let allowed = ctx.config.allowed_words in
  File_view.outline_patterns (Context.view ctx)
  |> List.filter_map (fun pattern ->
      let name = File_view.Reference.base pattern in
      match
        (check_value_name ~allowed name, File_view.Reference.loc pattern)
      with
      | Some expected, Some loc ->
          Some (Issue.v ~loc { value_name = name; expected })
      | _ -> None)

let pp ppf { value_name; expected } =
  Fmt.pf ppf "Value '%s' should use snake_case: '%s'" value_name expected

let rule =
  Rule.v ~code:"E310" ~title:"Value Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Values and function names should use snake_case (e.g., find_user, \
       create_channel). Short, descriptive, and lowercase with underscores. \
       This is the standard convention in OCaml for values and functions."
    ~examples:
      [ Example.bad Examples.E310.bad_ml; Example.good Examples.E310.good_ml ]
    ~pp (File check)
