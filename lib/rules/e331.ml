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
    flag those. Uses structural type analysis via [Parse.core_type] rather than
    string-suffix matching, so [int -> ('a, 'b) result option] and friends are
    detected correctly. *)
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

let prefix_type_to_string = function
  | Create -> "create_"
  | Make -> "make_"
  | Get -> "get_"
  | Find -> "find_"

let check (ctx : Context.file) =
  let outline_data = Context.outline ctx in
  let filename = ctx.filename in
  let allowed = ctx.config.allowed_words in
  let module_name =
    Filename.basename filename |> Filename.remove_extension
    |> String.lowercase_ascii
  in

  (* Check if a function name has redundant prefix *)
  let check_function_prefix name =
    let name_lower = String.lowercase_ascii name in

    (* Check for create_ prefix *)
    if String.starts_with ~prefix:"create_" name_lower then
      let suffix = String.sub name_lower 7 (String.length name_lower - 7) in
      if suffix <> "" then Some (Create, suffix) else None
      (* Check for make_ prefix *)
    else if String.starts_with ~prefix:"make_" name_lower then
      let suffix = String.sub name_lower 5 (String.length name_lower - 5) in
      if suffix <> "" then Some (Make, suffix) else None
      (* Check for get_ prefix *)
    else if String.starts_with ~prefix:"get_" name_lower then
      let suffix = String.sub name_lower 4 (String.length name_lower - 4) in
      if suffix <> "" then Some (Get, suffix) else None
      (* Check for find_ prefix *)
    else if String.starts_with ~prefix:"find_" name_lower then
      let suffix = String.sub name_lower 5 (String.length name_lower - 5) in
      if suffix <> "" then Some (Find, suffix) else None
    else None
  in

  (* Check for Module.create_module pattern *)
  let check_module_create_prefix name =
    let name_lower = String.lowercase_ascii name in
    if String.starts_with ~prefix:"create_" name_lower then
      let suffix = String.sub name_lower 7 (String.length name_lower - 7) in
      (* Check if suffix matches module name or is related to module *)
      if suffix = module_name || String.starts_with ~prefix:module_name suffix
      then Some (Create, "v")
      else None
    else None
  in

  List.filter_map
    (fun (item : Outline.item) ->
      let name = item.name in
      let location = Outline.location filename item in

      match (item.kind, location) with
      | Outline.Value, Some loc
        when (not (List.mem name allowed))
             && (not (is_stdlib_find_alias name))
             && not (is_find_option name item) -> (
          (* Check for regular function prefix patterns *)
          match check_function_prefix name with
          | Some (prefix_type, suggested) ->
              Some
                (Issue.v ~loc
                   {
                     function_name = name;
                     suggested_name = suggested;
                     prefix_type;
                     context = name;
                   })
          | None -> (
              (* Check for Module.create_module pattern *)
              match check_module_create_prefix name with
              | Some (prefix_type, suggested) ->
                  Some
                    (Issue.v ~loc
                       {
                         function_name = name;
                         suggested_name = suggested;
                         prefix_type;
                         context =
                           String.capitalize_ascii module_name ^ "." ^ name;
                       })
              | None -> None))
      | _ -> None)
    outline_data

let pp ppf { function_name = _; suggested_name; prefix_type; context } =
  let prefix_str = prefix_type_to_string prefix_type in
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
