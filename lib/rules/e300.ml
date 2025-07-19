(** E300: Variant Naming Convention *)

type payload = { variant : string; expected : string }

let check (ctx : Context.file) =
  Dump.check_elements (Context.dump ctx).variants
    (fun name ->
      if Naming.is_pascal_case name then Some (Naming.to_snake_case name)
      else None)
    (fun variant_name loc expected ->
      Issue.v ~loc { variant = variant_name; expected })

let pp ppf { variant; expected } =
  Fmt.pf ppf "Variant '%s' should use snake_case: '%s'" variant expected

let rule =
  Rule.v ~code:"E300" ~title:"Variant Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Variant constructors should use snake_case (e.g., My_variant, \
       Some_constructor). This matches the project's naming conventions."
    ~examples:[] ~pp (File check)
