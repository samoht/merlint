(** E315: Type Naming Convention *)

type payload = { type_name : string; expected : string }
(** Payload for bad type naming *)

let check ctx =
  File_view.outline_types (Context.view ctx)
  |> List.filter_map (fun type_ref ->
      let name = File_view.Reference.base type_ref in
      let expected = Naming.to_lowercase_snake_case name in
      if name <> expected then
        Option.map
          (fun loc -> Issue.v ~loc { type_name = name; expected })
          (File_view.Reference.loc type_ref)
      else None)

let pp ppf { type_name; expected } =
  Fmt.pf ppf "Type name '%s' should use snake_case: '%s'" type_name expected

let rule =
  Rule.v ~code:"E315" ~title:"Type Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Type names should use snake_case. The primary type in a module should \
       be named t, and identifiers should be id. This convention helps \
       maintain consistency across the codebase."
    ~examples:
      [ Example.bad Examples.E315.bad_ml; Example.good Examples.E315.good_ml ]
    ~pp (File check)
