(** E300: Variant Naming Convention *)

(** Check if a name follows PascalCase convention *)
let is_pascal_case name =
  let len = String.length name in
  if len = 0 then false
  else
    (* Must start with uppercase *)
    let first_ok = Char.uppercase_ascii name.[0] = name.[0] in
    (* Should not have underscores *)
    let no_underscores = not (String.contains name '_') in
    first_ok && no_underscores

let check typedtree =
  List.filter_map
    (fun (variant : Ast.elt) ->
      let variant_name = Ast.name_to_string variant.name in
      if not (is_pascal_case variant_name) then
        let location =
          match variant.location with
          | Some loc -> loc
          | None ->
              Location.create ~file:"unknown" ~start_line:1 ~start_col:1
                ~end_line:1 ~end_col:1
        in
        Some
          (Issue.Bad_variant_naming
             {
               variant = variant_name;
               location;
               expected = String.capitalize_ascii variant_name;
             })
      else None)
    typedtree.Typedtree.variants
