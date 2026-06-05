(** E332: Prefer 'v' Constructor *)

type payload = {
  function_name : string;
  module_context : string option;
      (* dotted path of enclosing modules, [None] at top level *)
}
(** Payload for constructor naming issues *)

let qualify module_context name =
  match module_context with Some path -> path ^ "." ^ name | None -> name

let check (ctx : Context.file) =
  let module Item = File_view.Item in
  let is_allowed module_context name =
    Config.allows ctx.config ~bare:name ~qualified:(qualify module_context name)
  in
  let rec walk ~module_context items =
    List.concat_map
      (fun item ->
        match Item.kind item with
        | Item.Value ->
            let name = Item.name item in
            let name_lower = String.lowercase_ascii name in
            (* Check for create/make functions that should be 'v' *)
            if
              (name_lower = "create" || name_lower = "make")
              && not (is_allowed module_context name)
            then
              [
                Issue.v ~loc:(Item.loc item)
                  { function_name = name; module_context };
              ]
            else []
        | Item.Module ->
            (* Descend, tracking the enclosing module path so the message can
               point at the qualified name to rename (e.g. 'Header.make'). *)
            let module_context =
              match module_context with
              | None -> Some (Item.name item)
              | Some path -> Some (path ^ "." ^ Item.name item)
            in
            walk ~module_context (Item.children item)
        | _ -> [])
      items
  in
  walk ~module_context:None (File_view.items (Context.view ctx))

let pp ppf { function_name; module_context } =
  let qualified = qualify module_context function_name in
  Fmt.pf ppf
    "Function '%s' should be named 'v' - this is the idiomatic constructor \
     name in OCaml modules"
    qualified

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
