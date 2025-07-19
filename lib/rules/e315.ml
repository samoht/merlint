(** E315: Type Naming Convention *)

type payload = { type_name : string; expected : string }
(** Payload for bad type naming *)

let check ctx =
  (* Check type names *)
  let ast = Context.dump ctx in
  List.filter_map
    (fun (type_elt : Dump.elt) ->
      let name_str = type_elt.name.base in
      if
        name_str <> "t" && name_str <> "id"
        && name_str <> Naming.to_snake_case name_str
      then
        match Dump.location type_elt with
        | Some loc ->
            Some
              (Issue.v ~loc
                 {
                   type_name = name_str;
                   expected = Naming.to_snake_case name_str;
                 })
        | None -> None
      else None)
    ast.types

let pp ppf { type_name; expected } =
  Fmt.pf ppf "Type name '%s' should use snake_case: '%s'" type_name expected

let rule =
  Rule.v ~code:"E315" ~title:"Type Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Type names should use snake_case, except for the conventional names 't' \
       and 'id'. This convention helps maintain consistency across the \
       codebase."
    ~examples:[] ~pp (File check)
