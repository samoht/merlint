(** E310: Value Naming Convention *)

type payload = { value_name : string; expected : string }
(** Payload for bad value naming *)

let check_value_name name =
  let expected = Naming.to_snake_case name in
  if name <> expected && name <> String.lowercase_ascii name then Some expected
  else None

let check ctx =
  (* Check value names *)
  Dump.check_elements (Context.dump ctx).patterns check_value_name
    (fun name_str loc expected ->
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
    ~examples:[] ~pp (File check)
