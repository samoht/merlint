(** E300: Variant Naming Convention *)

type payload = { variant : string; expected : string }

let check (ctx : Context.file) =
  Dump.check_elements (Context.dump ctx).variants
    (fun name ->
      (* For qualified names, only check the basename *)
      let name_to_check =
        if String.contains name '.' then
          (* Get everything after the last dot *)
          let parts = String.split_on_char '.' name in
          List.hd (List.rev parts)
        else name
      in
      (* Standard library constructors are allowed to keep PascalCase *)
      if List.mem name_to_check [ "Some"; "None"; "Ok"; "Error" ] then None
      else if Naming.is_pascal_case name_to_check then
        (* PascalCase needs to be converted to snake_case *)
        Some (Naming.to_capitalized_snake_case name_to_check)
      else None)
    (fun variant_name loc expected ->
      Issue.v ~loc { variant = variant_name; expected })

let pp ppf { variant; expected } =
  Fmt.pf ppf "Variant '%s' should use Snake_case: '%s'" variant expected

let rule =
  Rule.v ~code:"E300" ~title:"Variant Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Variant constructors should use Snake_case (e.g., Waiting_for_input, \
       Processing_data), not CamelCase. This matches the project's naming \
       conventions."
    ~examples:[] ~pp (File check)
