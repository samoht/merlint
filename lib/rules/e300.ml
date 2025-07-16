(** E300: Variant Naming Convention *)

let check ctx =
  Traverse.check_elements (Context.ast ctx).variants
    (fun name ->
      if not (Traverse.is_pascal_case name) then
        Some (Traverse.to_pascal_case name)
      else None)
    (fun variant_name loc expected ->
      Issue.bad_variant_naming ~variant:variant_name ~loc ~expected)
