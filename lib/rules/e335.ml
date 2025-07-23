(** E335: Used Underscore-Prefixed Binding *)

type payload = { binding_name : string; usage_locations : Location.t list }
(** Payload for used underscore binding issues *)

let check ctx =
  (* First, collect all underscore-prefixed pattern bindings *)
  let underscore_bindings =
    List.filter_map
      (fun (elt : Dump.elt) ->
        let name = Dump.name_to_string elt.name in
        if String.length name > 0 && name.[0] = '_' then
          match Dump.location elt with
          | Some loc -> Some (name, loc)
          | None -> None
        else None)
      (Context.dump ctx).patterns
  in

  (* For each underscore binding, check if it's used in identifiers *)
  List.filter_map
    (fun (binding_name, binding_loc) ->
      (* Find all usages of this binding *)
      let usage_locations =
        List.filter_map
          (fun (elt : Dump.elt) ->
            let ident_name = Dump.name_to_string elt.name in
            if ident_name = binding_name then Dump.location elt else None)
          (Context.dump ctx).identifiers
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
    ~examples:
      [ Example.bad Examples.E335.bad_ml; Example.good Examples.E335.good_ml ]
    ~pp (File check)
