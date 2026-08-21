(** E330: Redundant Module Name *)

type payload = { item_name : string; module_name : string; item_type : string }
(** Payload for redundant module name issues *)

(** Check if an item name has redundant module prefix *)
let has_redundant_prefix item_name_lower module_name filename =
  (* Special cases that are idiomatic and should not be flagged *)
  if
    (item_name_lower = "pp" && module_name = "pp")
    || (item_name_lower = "main" && module_name = "main")
    ||
    (* Test functions in test files are entry points and idiomatic. Match
       both `test_foo.ml` (module `test_foo`, items `test_*`) and the bare
       `test.ml` convention (module `test`, items `test_*`). *)
    (String.starts_with ~prefix:"test_" module_name || module_name = "test")
    && String.starts_with ~prefix:"test_" item_name_lower
    && File_kind.is_ml filename
  then false
  else
    String.starts_with ~prefix:(module_name ^ "_") item_name_lower
    || item_name_lower = module_name

(** Create redundant module name issue *)
let redundant_name_issue item_name module_name location item_type =
  Issue.v ~loc:location
    { item_name; module_name = String.capitalize_ascii module_name; item_type }

let check (ctx : Context.file) =
  let filename = Context.filename ctx in
  let module_name =
    Filename.basename filename |> Filename.remove_extension
    |> String.lowercase_ascii
  in
  List.filter_map
    (fun item ->
      let module Item = File_view.Item in
      let name = Item.name item in
      let location = Some (Item.loc item) in
      let item_name_lower = String.lowercase_ascii name in
      if has_redundant_prefix item_name_lower module_name filename then
        match (Item.kind item, location) with
        | Item.Value, Some loc ->
            let kind_label =
              match Item.type_sig item with
              | Some typ when File_view.Type_view.is_function typ -> "function"
              | _ -> "value"
            in
            Some (redundant_name_issue name module_name loc kind_label)
        | Item.Type, Some loc ->
            Some (redundant_name_issue name module_name loc "type")
        | _ -> None
      else None)
    (File_view.typed_items (Context.view ctx))

let pp ppf { item_name; module_name; item_type } =
  Fmt.pf ppf "%s '%s' has redundant module prefix from %s"
    (String.capitalize_ascii item_type)
    item_name module_name

let rule =
  Rule.v ~code:"E330" ~title:"Redundant Module Name"
    ~category:Naming_conventions
    ~hint:
      "Avoid prefixing type or function names with the module name. The module \
       already provides the namespace, so Message.message_type should just be \
       Message.t. Exception: Pp.pp is idiomatic for pretty-printing modules."
    ~examples:
      [
        Example.bad Examples.E330.Bad.process_ml;
        Example.good Examples.E330.Good.process_ml;
      ]
    ~pp (File check)
