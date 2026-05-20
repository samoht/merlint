open Examples
(** E405: Missing Value Documentation *)

type payload = { value_name : string; location : Location.t }

let missing_doc item =
  let module Item = File_view.Item in
  Item.kind item = Item.Value && Option.is_none (Item.doc item)

let check (ctx : Context.file) =
  if not (File_kind.is_mli ctx.filename) then []
  else if
    match ctx.project_index with
    | Some idx ->
        Project_index.is_generated_source_file idx (Fpath.v ctx.filename)
    | None -> false
  then []
  else
    Context.view ctx |> File_view.value_items
    |> List.filter_map (fun item ->
        if missing_doc item then
          let loc = File_view.Item.loc item in
          Some
            (Issue.v ~loc
               { value_name = File_view.Item.name item; location = loc })
        else None)

let pp ppf { value_name; location = _ } =
  Fmt.pf ppf "Public value '%s' is missing documentation" value_name

let rule =
  Rule.v ~code:"E405" ~title:"Missing Value Documentation"
    ~category:Documentation
    ~hint:
      "All public values should have documentation explaining their purpose \
       and usage. Add doc comments (** ... *) before or after value \
       declarations in .mli files."
    ~examples:[ Example.bad E405.bad_mli; Example.good E405.good_mli ]
    ~pp (File check)
