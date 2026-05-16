(** E335: Used Underscore-Prefixed Binding *)

type payload = {
  binding_name : string;
  usage_locations : Merlin.Location.t list;
}
(** Payload for used underscore binding issues *)

let check ctx =
  let view = Context.view ctx in
  let bindings =
    File_view.outline_patterns view
    |> List.filter_map (fun pattern ->
        let name = File_view.Reference.base pattern in
        if
          String.length name > 0
          && name.[0] = '_'
          && not (String.starts_with ~prefix:"__" name)
        then
          Option.map (fun loc -> (name, loc)) (File_view.Reference.loc pattern)
        else None)
  in
  let usages =
    File_view.outline_identifiers view
    |> List.filter_map (fun ident ->
        Option.map
          (fun loc -> (File_view.Reference.base ident, loc))
          (File_view.Reference.loc ident))
  in
  List.filter_map
    (fun (binding_name, binding_loc) ->
      let usage_locations =
        List.filter_map
          (fun (name, loc) -> if name = binding_name then Some loc else None)
          usages
      in
      if usage_locations = [] then None
      else Some (Issue.v ~loc:binding_loc { binding_name; usage_locations }))
    bindings

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
       pattern '_' instead. Note: PPX-generated code with double underscore \
       prefix (like '__ppx_generated') is excluded from this check."
    ~examples:
      [ Example.bad Examples.E335.bad_ml; Example.good Examples.E335.good_ml ]
    ~pp (File check)
