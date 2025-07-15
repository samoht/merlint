(** E320: Long Identifier Names *)

let check (typedtree : Typedtree.t) =
  let max_underscores = 4 in
  let all_elts =
    typedtree.Typedtree.identifiers @ typedtree.Typedtree.patterns
    @ typedtree.Typedtree.modules @ typedtree.Typedtree.types
    @ typedtree.Typedtree.exceptions @ typedtree.Typedtree.variants
  in
  all_elts
  |> List.filter_map (fun (elt : Ast.elt) ->
         (* Only check the base name, not the full qualified name *)
         let base_name = elt.name.base in
         let underscore_count =
           String.fold_left
             (fun count c -> if c = '_' then count + 1 else count)
             0 base_name
         in
         if underscore_count > max_underscores && String.length base_name > 5
         then
           match elt.location with
           | Some loc ->
               (* Use full name for display but count underscores only in base *)
               let full_name = Ast.name_to_string elt.name in
               Some
                 (Issue.Long_identifier_name
                    {
                      name = full_name;
                      location = loc;
                      underscore_count;
                      threshold = max_underscores;
                    })
           | None -> None
         else None)
