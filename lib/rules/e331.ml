(** E331: Redundant Function Prefixes *)

(** Stdlib-aligned [find_*] names where stripping the [find_] prefix would lose
    information: [List.find_all], [Hashtbl.find_all], [List.find_map], etc. The
    bare suffix ([all], [map]) alone isn't descriptive enough, and the stdlib
    precedent establishes the full name as the natural form. *)
let is_stdlib_find_alias name =
  name = "find_all" || name = "find_map" || name = "find_many"
  || name = "find_index" || name = "find_last" || name = "find_first"

(** [find_*] functions returning [_ option] are the canonical naming for partial
    lookups (matching E325, which positively recommends [find_] for option
    returns). Stripping the prefix would strip the partiality signal, so do not
    flag those. Uses structural type analysis via [Parsetree.core_type] rather
    than string-suffix matching, so [int -> ('a, 'b) result option] and friends
    are detected correctly. *)
let is_find_option name (item : Outline.item) =
  String.starts_with ~prefix:"find_" (String.lowercase_ascii name)
  && Outline.returns_option item

type prefix_type = Create | Make | Get | Find

type payload = {
  function_name : string;
  suggested_name : string;
  prefix_type : prefix_type;
  context : string; (* "function" or "Module.function" *)
}
(** Payload for redundant prefix issues *)

let string_of_prefix_type = function
  | Create -> "create_"
  | Make -> "make_"
  | Get -> "get_"
  | Find -> "find_"

let prefixed_name name =
  let name_lower = String.lowercase_ascii name in
  let prefixes =
    [ ("create_", Create); ("make_", Make); ("get_", Get); ("find_", Find) ]
  in
  List.find_map
    (fun (prefix, prefix_type) ->
      if String.starts_with ~prefix name_lower then
        let suffix =
          String.sub name_lower (String.length prefix)
            (String.length name_lower - String.length prefix)
        in
        if suffix = "" then None else Some (prefix_type, suffix)
      else None)
    prefixes

let module_create_prefix ~module_name name =
  let name_lower = String.lowercase_ascii name in
  match prefixed_name name_lower with
  | Some (Create, suffix)
    when suffix = module_name || String.starts_with ~prefix:module_name suffix
    ->
      Some (Create, "v")
  | _ -> None

let redundant_prefix_issue ~loc ~name ~suggested_name ~prefix_type ~context =
  Issue.v ~loc { function_name = name; suggested_name; prefix_type; context }

let item_issue ~filename ~allowed ~module_name (item : Outline.item) =
  let name = item.name in
  match (item.kind, Outline.location filename item) with
  | Outline.Value, Some loc
    when (not (List.mem name allowed))
         && (not (is_stdlib_find_alias name))
         && not (is_find_option name item) -> (
      match prefixed_name name with
      | Some (prefix_type, suggested_name) ->
          Some
            (redundant_prefix_issue ~loc ~name ~suggested_name ~prefix_type
               ~context:name)
      | None -> (
          match module_create_prefix ~module_name name with
          | Some (prefix_type, suggested_name) ->
              let context = String.capitalize_ascii module_name ^ "." ^ name in
              Some
                (redundant_prefix_issue ~loc ~name ~suggested_name ~prefix_type
                   ~context)
          | None -> None))
  | _ -> None

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let allowed = ctx.config.allowed_words in
  let module_name =
    Filename.basename filename |> Filename.remove_extension
    |> String.lowercase_ascii
  in
  List.filter_map
    (item_issue ~filename ~allowed ~module_name)
    (Context.outline ctx)

let pp ppf { function_name = _; suggested_name; prefix_type; context } =
  let prefix_str = string_of_prefix_type prefix_type in
  Fmt.pf ppf
    "Function '%s' has redundant '%s' prefix - consider '%s' instead. %s \
     functions can often omit the prefix when the function name alone is \
     descriptive."
    context prefix_str suggested_name
    (String.capitalize_ascii prefix_str)

let rule =
  Rule.v ~code:"E331" ~title:"Redundant Function Prefixes"
    ~category:Naming_conventions
    ~hint:
      "Functions prefixed with 'create_', 'make_', 'get_', or 'find_' can \
       often omit the prefix when the remaining name is descriptive enough. \
       For example, 'create_user' can be just 'user', 'make_widget' can be \
       'widget', 'get_name' can be 'name', and 'find_user' can be 'user' \
       (returning option). Keep the prefix only when it adds meaningful \
       distinction or when the bare name would be ambiguous. In modules, \
       'Module.create_module' should be 'Module.v'."
    ~examples:
      [ Example.bad Examples.E331.bad_ml; Example.good Examples.E331.good_ml ]
    ~pp (File check)
