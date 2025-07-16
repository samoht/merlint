(** E330: Redundant Module Name *)

(** Check if an item name has redundant module prefix *)
let has_redundant_prefix item_name_lower module_name =
  String.starts_with ~prefix:(module_name ^ "_") item_name_lower
  || item_name_lower = module_name

(** Create redundant module name issue *)
let create_redundant_name_issue item module_name location item_type =
  Issue.Redundant_module_name
    {
      item_name = item.Outline.name;
      module_name = String.capitalize_ascii module_name;
      location;
      item_type;
    }

(* Helper to check if a type signature is a function type *)
let is_function_type type_sig = String.contains type_sig '-'

let extract_outline_location filename (item : Outline.item) =
  match item.range with
  | Some range ->
      Some
        (Location.create ~file:filename ~start_line:range.start.line
           ~start_col:range.start.col ~end_line:range.start.line
           ~end_col:range.start.col)
  | None -> None

let check ctx =
  match ctx with
  | Context.File file_ctx ->
      let filename = file_ctx.Context.filename in
      let outline = Context.outline ctx in
      (* Extract module name from filename *)
      let module_name =
        filename |> Filename.basename |> Filename.chop_extension
        |> String.lowercase_ascii
      in
      Logs.debug (fun m ->
          m "Checking redundant module name for %s (module: %s)" filename
            module_name);
      Logs.debug (fun m -> m "Found %d outline items" (List.length outline));
      List.filter_map
        (fun (item : Outline.item) ->
          let item_name_lower = String.lowercase_ascii item.name in
          let location = extract_outline_location filename item in
          match (item.kind, location) with
          | Outline.Value, Some loc
            when is_function_type (Option.value ~default:"" item.type_sig)
                 && has_redundant_prefix item_name_lower module_name ->
              Some (create_redundant_name_issue item module_name loc "function")
          | Outline.Type, Some loc
            when has_redundant_prefix item_name_lower module_name ->
              Some (create_redundant_name_issue item module_name loc "type")
          | _ -> None)
        outline
  | Context.Project _ ->
      failwith "E330 is a file-level rule but received project context"
