(** E335: Used Underscore-Prefixed Binding *)

let check (typedtree : Typedtree.t) =
  let open Typedtree in
  (* First, collect all underscore-prefixed pattern bindings *)
  let underscore_bindings =
    typedtree.patterns
    |> List.filter_map (fun (elt : Ast.elt) ->
           let name = Ast.name_to_string elt.name in
           if String.length name > 0 && name.[0] = '_' then
             match elt.location with
             | Some loc -> Some (name, loc)
             | None -> None
           else None)
  in

  (* For each underscore binding, check if it's used in identifiers *)
  List.filter_map
    (fun (binding_name, binding_loc) ->
      (* Find all usages of this binding *)
      let usage_locations =
        typedtree.identifiers
        |> List.filter_map (fun (elt : Ast.elt) ->
               let ident_name = Ast.name_to_string elt.name in
               if ident_name = binding_name then elt.location else None)
      in

      (* If the binding is used, create an issue *)
      if usage_locations <> [] then
        Some
          (Issue.Used_underscore_binding
             { binding_name; location = binding_loc; usage_locations })
      else None)
    underscore_bindings
