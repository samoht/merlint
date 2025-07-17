(** E320: Long Identifier Names *)

type payload = { name : string; kind : string; length : int; max_length : int }
(** Payload for long identifier name *)

let check ctx =
  let max_underscores = 4 in
  let ast = Context.ast ctx in
  let all_elts =
    ast.identifiers @ ast.patterns @ ast.modules @ ast.types @ ast.exceptions
    @ ast.variants
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
              (Issue.v ~loc
                 {
                   name = full_name;
                   kind = "identifier";
                   length = underscore_count;
                   max_length = max_underscores;
                 })
        | None -> None
      else None)

let pp ppf { name; kind = _; length; max_length } =
  Fmt.pf ppf "Identifier '%s' has %d underscores (max %d)" name length
    max_length

let rule =
  Rule.v ~code:"E320" ~title:"Long Identifier Names"
    ~category:Naming_conventions
    ~hint:
      "Avoid using too many underscores in identifier names as they make code \
       harder to read. Consider using more descriptive names or restructuring \
       the code to avoid deeply nested concepts."
    ~examples:[] ~pp (File check)
