(** E310: Value Naming Convention *)

type payload = { value_name : string; expected : string }
(** Payload for bad value naming *)

(** Allow trailing single uppercase letter suffixes like _A, _B, _C in
    snake_case names. These are commonly used for spec variants, type
    parameters, or other meaningful single-letter identifiers. *)
let is_valid_snake_case_with_suffix name =
  let len = String.length name in
  if len < 3 then false
  else if name.[len - 2] = '_' then
    let suffix = name.[len - 1] in
    let prefix = String.sub name 0 (len - 2) in
    suffix >= 'A' && suffix <= 'Z' && prefix = String.lowercase_ascii prefix
  else false

let check_value_name name =
  (* Skip names starting with uppercase: these are first-class module bindings
     like (module M) which must be uppercase in OCaml *)
  if name <> "" && name.[0] >= 'A' && name.[0] <= 'Z' then None
  else
    let expected = Naming.to_lowercase_snake_case name in
    if name <> expected && name <> String.lowercase_ascii name then
      if is_valid_snake_case_with_suffix name then None else Some expected
    else None

let check (ctx : Context.file) =
  let filename = ctx.filename in
  (* Check value names *)
  Merlin.Dump.check_elements ~full_path:filename (Context.dump ctx).patterns
    check_value_name (fun name_str loc expected ->
      Issue.v ~loc { value_name = name_str; expected })

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
