(** E300: Variant Naming Convention *)

type payload = { variant : string; expected : string }

let check (ctx : Context.file) =
  Dump.check_elements (Context.dump ctx).variants
    (fun name ->
      if not (Naming.is_pascal_case name) then Some (Naming.to_pascal_case name)
      else None)
    (fun variant_name loc expected ->
      Issue.v ~loc { variant = variant_name; expected })

let pp ppf { variant; expected } =
  Fmt.pf ppf "Variant '%s' should use PascalCase: '%s'" variant expected

let rule =
  Rule.v ~code:"E300" ~title:"Variant Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Variant constructors should use PascalCase (e.g., MyVariant, \
       SomeConstructor). This is the standard convention in OCaml for variant \
       constructors."
    ~examples:[] ~pp (File check)
