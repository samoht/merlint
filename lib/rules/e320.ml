(** E320: Long Identifier Names *)

let check ctx =
  let max_underscores = 4 in
  let all_elts =
    (Context.ast ctx).identifiers @ (Context.ast ctx).patterns
    @ (Context.ast ctx).modules @ (Context.ast ctx).types
    @ (Context.ast ctx).exceptions @ (Context.ast ctx).variants
  in
  Traverse.filter_map_elements all_elts (fun (elt : Ast.elt) ->
      (* Only check the base name, not the full qualified name *)
      let base_name = elt.name.base in
      let underscore_count =
        String.fold_left
          (fun count c -> if c = '_' then count + 1 else count)
          0 base_name
      in
      if underscore_count > max_underscores && String.length base_name > 5 then
        match Traverse.extract_location elt with
        | Some loc ->
            (* Use full name for display but count underscores only in base *)
            let full_name = Ast.name_to_string elt.name in
            Some
              (Issue.long_identifier_name ~name:full_name ~loc ~underscore_count
                 ~threshold:max_underscores)
        | None -> None
      else None)
