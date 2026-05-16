(** E300: Variant Naming Convention *)

type payload = { variant : string; expected : string }

let check (ctx : Context.file) =
  let allowed = ctx.config.allowed_words in
  File_view.outline_variant_definitions (Context.view ctx)
  |> List.filter_map (fun variant ->
      let name = File_view.Reference.base variant in
      let loc = File_view.Reference.loc variant in
      if not (List.mem name allowed) then
        let expected = Naming.to_capitalized_snake_case name in
        if expected <> name then
          Option.map (fun loc -> Issue.v ~loc { variant = name; expected }) loc
        else None
      else None)

let pp ppf { variant; expected } =
  Fmt.pf ppf "Variant '%s' should use Snake_case: '%s'" variant expected

let rule =
  Rule.v ~code:"E300" ~title:"Variant Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Variant constructors should use Snake_case (e.g., Waiting_for_input, \
       Processing_data), not CamelCase. This matches the project's naming \
       conventions."
    ~examples:
      [ Example.bad Examples.E300.bad_ml; Example.good Examples.E300.good_ml ]
    ~pp (File check)
