(** E332: Prefer 'v' Constructor *)

type payload = {
  function_name : string;
  module_context : string option; (* Some "Module" or None for top-level *)
}
(** Payload for constructor naming issues *)

let check (ctx : Context.file) =
  List.filter_map
    (fun item ->
      let module Item = File_view.Item in
      let name = Item.name item in
      let name_lower = String.lowercase_ascii name in
      let location = Some (Item.loc item) in

      match (Item.kind item, location) with
      | Item.Value, Some loc ->
          (* Check for create/make functions that should be 'v' *)
          if name_lower = "create" || name_lower = "make" then
            Some (Issue.v ~loc { function_name = name; module_context = None })
          else None
      | _ -> None)
    (File_view.items (Context.view ctx))

let pp ppf { function_name; module_context = _ } =
  Fmt.pf ppf
    "Function '%s' should be named 'v' - this is the idiomatic constructor \
     name in OCaml modules"
    function_name

let rule =
  Rule.v ~code:"E332" ~title:"Prefer 'v' Constructor"
    ~category:Naming_conventions
    ~hint:
      "In OCaml modules, the idiomatic name for the primary constructor is 'v' \
       rather than 'create' or 'make'. This follows the convention used by \
       many standard libraries. For example, 'Module.create' should be \
       'Module.v'. This makes the API more consistent and idiomatic."
    ~examples:
      [ Example.bad Examples.E332.bad_ml; Example.good Examples.E332.good_ml ]
    ~pp (File check)
