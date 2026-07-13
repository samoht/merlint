(** E325: Function Naming Convention *)

type payload = { function_name : string; expected : string }

(** A type-variable [Ptyp_var "a"] means merlin couldn't resolve the type; skip
    the rule rather than guess. *)
let issue_for_return_shape ~loc ~name ~is_option ~is_collection =
  if (String.starts_with ~prefix:"get_" name || name = "get") && is_option then
    Some
      (Issue.v ~loc
         {
           function_name = name;
           expected =
             (if name = "get" then "find"
              else
                let suffix = String.sub name 4 (String.length name - 4) in
                "find_" ^ suffix);
         })
  else if
    (String.starts_with ~prefix:"find_" name || name = "find")
    && (not is_option) && not is_collection
  then
    Some
      (Issue.v ~loc
         {
           function_name = name;
           expected =
             (if name = "find" then "get"
              else
                let suffix = String.sub name 5 (String.length name - 5) in
                "get_" ^ suffix);
         })
  else None

let check_single_function item loc =
  let module Item = File_view.Item in
  match (Item.kind item, Item.type_sig item) with
  | Item.Value, Some typ when File_view.Type_view.is_function typ -> (
      let n = Item.name item in
      let return_type = File_view.Type_view.return_type typ in
      match return_type with
      | None -> None
      | Some ret when File_view.Type_view.is_variable ret -> None
      | Some ret ->
          issue_for_return_shape ~loc ~name:n
            ~is_option:(File_view.Type_view.returns_option typ)
            ~is_collection:
              (File_view.Type_view.is_list ret ~elem:(Fun.const true)))
  | _ -> None

let check (ctx : Context.file) =
  List.filter_map
    (fun item ->
      (* allowed_words exempts spec-mandated names (a Cryptoki client's
         find_objects mirrors C_FindObjects) from the return-shape
         convention. *)
      let name = File_view.Item.name item in
      if Config.allows ctx.config ~bare:name ~qualified:name then None
      else check_single_function item (File_view.Item.loc item))
    (File_view.items (Context.view ctx))

let pp ppf { function_name; expected } =
  Fmt.pf ppf "Function '%s' naming convention: consider '%s'" function_name
    expected

let rule =
  Rule.v ~code:"E325" ~title:"Function Naming Convention"
    ~category:Naming_conventions
    ~hint:
      "Functions that return option types should be prefixed with 'find_', \
       while functions that return non-option types should be prefixed with \
       'get_'. This convention helps communicate the function's behavior to \
       callers."
    ~examples:
      [ Example.bad Examples.E325.bad_ml; Example.good Examples.E325.good_ml ]
    ~pp (File check)
