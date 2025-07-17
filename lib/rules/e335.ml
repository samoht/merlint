(** E335: Used Underscore-Prefixed Binding *)

type payload = { binding_name : string; usage_locations : Location.t list }
(** Payload for used underscore binding issues *)

let check ctx =
  (* First, collect all underscore-prefixed pattern bindings *)
  let underscore_bindings =
    Helpers.filter_map_elements (Context.ast ctx).patterns
      (fun (elt : Ast.elt) ->
        let name = Ast.name_to_string elt.name in
        if String.length name > 0 && name.[0] = '_' then
          match Helpers.extract_location elt with
          | Some loc -> Some (name, loc)
          | None -> None
        else None)
  in

  (* For each underscore binding, check if it's used in identifiers *)
  List.filter_map
    (fun (binding_name, binding_loc) ->
      (* Find all usages of this binding *)
      let usage_locations =
        Helpers.filter_map_elements (Context.ast ctx).identifiers
          (fun (elt : Ast.elt) ->
            let ident_name = Ast.name_to_string elt.name in
            if ident_name = binding_name then Helpers.extract_location elt
            else None)
      in

      (* If the binding is used, create an issue *)
      if usage_locations <> [] then
        Some (Issue.v ~loc:binding_loc { binding_name; usage_locations })
      else None)
    underscore_bindings

let pp ppf { binding_name; usage_locations } =
  let usage_count = List.length usage_locations in
  Fmt.pf ppf
    "Underscore-prefixed binding '%s' is used %d time%s - underscore prefix \
     indicates unused bindings"
    binding_name usage_count
    (if usage_count = 1 then "" else "s")

let rule =
  Rule.v ~code:"E335" ~title:"Used Underscore-Prefixed Binding"
    ~category:Rule.Naming_conventions
    ~hint:
      "Bindings prefixed with underscore (like '_x') indicate they are meant \
       to be unused. If you need to use the binding, remove the underscore \
       prefix. If the binding is truly unused, consider using a wildcard \
       pattern '_' instead."
    ~examples:[] ~pp (File check)
