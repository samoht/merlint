(** E420: Missing Odoc Cross-Reference Links *)

module String_map = Map.Make (String)
module String_set = Set.Make (String)

type component = { name : string; kind : File_view.Item.kind }
type target = { path : component list }

type payload = {
  documented_name : string;
  reference : string;
  target : target;
  location : Location.t;
}

let odoc_prefix = function
  | File_view.Item.Value -> "val"
  | Type -> "type"
  | Module -> "module"
  | Module_type -> "module-type"
  | Class -> "class"
  | Class_type -> "class-type"
  | Constructor -> "constructor"
  | Exception -> "exception"
  | Extension -> "extension"
  | Field -> "field"
  | Method -> "method"
  | Instance_variable -> "instance-variable"

let kind_name = function
  | File_view.Item.Value -> "value"
  | Type -> "type"
  | Module -> "module"
  | Module_type -> "module type"
  | Class -> "class"
  | Class_type -> "class type"
  | Constructor -> "constructor"
  | Exception -> "exception"
  | Extension -> "extension"
  | Field -> "field"
  | Method -> "method"
  | Instance_variable -> "instance variable"

let component_link component =
  Fmt.str "%s-%s" (odoc_prefix component.kind) component.name

let link target =
  target.path |> List.map component_link |> String.concat "." |> Fmt.str "{!%s}"

let name_path (prefix : component list) name =
  match prefix with
  | [] -> name
  | _ ->
      String.concat "."
        (List.map (fun (c : component) -> c.name) prefix @ [ name ])

let target_kind target =
  match List.rev target.path with
  | [] -> File_view.Item.Value
  | last :: _ -> last.kind

(* A declaration's scope: the module path a documentation comment sits in, and
   whether the names declared there are reachable unqualified from it. Values
   and types of a module are; a class's methods and instance variables are
   not, they need the class in the path. *)
type scope = { modules : string list; visible : bool }

let root_scope = { modules = []; visible = true }
let scope_key scope = String.concat "." scope.modules

let enter scope (component : component) =
  match component.kind with
  | File_view.Item.Module | Module_type ->
      { scope with modules = scope.modules @ [ component.name ] }
  | Type | Extension -> scope
  | _ -> { scope with visible = false }

(* Where an unqualified reference can resolve, per scope, alongside the dotted
   paths that name everything from the file's root. A name bound twice in one
   scope maps to [None]: odoc would pick one of them and the rule has no way to
   tell which the prose meant, so it proposes nothing. *)
type index = {
  paths : target String_map.t;
  scoped : target option String_map.t String_map.t;
}

let empty_index = { paths = String_map.empty; scoped = String_map.empty }

let add_scoped index scope name target =
  if not scope.visible then index
  else
    let key = scope_key scope in
    let names =
      String_map.find_opt key index.scoped
      |> Option.value ~default:String_map.empty
      |> String_map.update name (function
        | None -> Some (Some target)
        | Some _ -> Some None)
    in
    { index with scoped = String_map.add key names index.scoped }

let rec add_item scope (prefix : component list) index item =
  let name = File_view.Item.name item in
  let component : component = { name; kind = File_view.Item.kind item } in
  let target = { path = prefix @ [ component ] } in
  let index =
    {
      index with
      paths = String_map.add (name_path prefix name) target index.paths;
    }
  in
  let index = add_scoped index scope name { path = [ component ] } in
  List.fold_left
    (add_item (enter scope component) target.path)
    index
    (File_view.Item.children item)

let index items = List.fold_left (add_item root_scope []) empty_index items

let parent_modules modules =
  match List.rev modules with [] -> None | _ :: rest -> Some (List.rev rest)

(* Resolve as odoc does: the innermost scope that binds the name wins, and the
   search stops there rather than reaching an outer binding it shadows. *)
let rec resolve_scoped scoped modules name =
  let bound =
    match String_map.find_opt (String.concat "." modules) scoped with
    | None -> None
    | Some names -> String_map.find_opt name names
  in
  match bound with
  | Some target -> target
  | None -> (
      match parent_modules modules with
      | None -> None
      | Some outer -> resolve_scoped scoped outer name)

let resolve index scope reference =
  if String.contains reference '.' then
    String_map.find_opt reference index.paths
  else resolve_scoped index.scoped scope.modules reference

(* Names OCaml predefines. Prose writing [None], [Error] or [int] means the
   predefined one even in a package that exports a constructor or type of that
   name, so linking would send the reader somewhere the prose never meant. *)
let predefined =
  String_set.of_list
    [
      "None";
      "Some";
      "Ok";
      "Error";
      "true";
      "false";
      "int";
      "char";
      "string";
      "bytes";
      "float";
      "bool";
      "unit";
      "exn";
      "array";
      "list";
      "option";
      "result";
      "int32";
      "int64";
      "nativeint";
      "lazy_t";
      "ref";
      "format";
      "Match_failure";
      "Assert_failure";
      "Invalid_argument";
      "Failure";
      "Not_found";
      "Out_of_memory";
      "Stack_overflow";
      "Sys_error";
      "End_of_file";
      "Division_by_zero";
      "Sys_blocked_io";
      "Undefined_recursive_module";
      "Exit";
    ]

let trim = String.trim
let words s = String.split_on_char ' ' s |> List.filter (fun s -> trim s <> "")

let unlabel s =
  let s = trim s in
  let len = String.length s in
  if len > 0 && (s.[0] = '~' || s.[0] = '?') then String.sub s 1 (len - 1)
  else s

let leading_code_span doc =
  let doc = trim doc in
  if String.length doc = 0 || doc.[0] <> '[' then None
  else
    match String.index_from_opt doc 1 ']' with
    | None -> None
    | Some stop -> Some (String.sub doc 1 (stop - 1))

let arg_label = function
  | Ocaml_parsing.Asttypes.Labelled name | Optional name -> Some name
  | Nolabel -> None

let arg_labels item =
  File_view.Item.arg_labels item |> List.filter_map arg_label

let documented_args item doc =
  let self = File_view.Item.name item in
  match leading_code_span doc with
  | None -> []
  | Some span -> (
      match words span with
      | name :: args when name = self -> List.map unlabel args
      | _ -> [])

(* The names a declaration owns: itself, its own arguments, and its own
   constructors, fields or members. A doc naming what it declares refers to
   nothing else, so there is nothing to link to. *)
let owned_names item doc =
  let children = File_view.Item.children item |> List.map File_view.Item.name in
  (File_view.Item.name item :: (arg_labels item @ documented_args item doc))
  @ children
  |> String_set.of_list

let substring_from s start pattern =
  let plen = String.length pattern in
  let rec loop i =
    if i + plen > String.length s then None
    else if String.sub s i plen = pattern then Some i
    else loop (i + 1)
  in
  loop start

let code_spans doc =
  let len = String.length doc in
  let rec loop acc i =
    if i >= len then List.rev acc
    else if i + 1 < len && doc.[i] = '{' && doc.[i + 1] = '[' then
      let next =
        match substring_from doc (i + 2) "]}" with
        | Some stop -> stop + 2
        | None -> len
      in
      loop acc next
    else if i + 1 < len && doc.[i] = '{' && doc.[i + 1] = 'v' then
      let next =
        match substring_from doc (i + 2) "v}" with
        | Some stop -> stop + 2
        | None -> len
      in
      loop acc next
    else if i + 1 < len && doc.[i] = '{' && doc.[i + 1] = '!' then
      let next =
        match String.index_from_opt doc (i + 2) '}' with
        | Some stop -> stop + 1
        | None -> len
      in
      loop acc next
    else if doc.[i] = '[' then
      match String.index_from_opt doc (i + 1) ']' with
      | None -> List.rev acc
      | Some stop ->
          let content = String.sub doc (i + 1) (stop - i - 1) |> trim in
          loop (content :: acc) (stop + 1)
    else loop acc (i + 1)
  in
  loop [] 0

let check_doc index scope item doc =
  let doc_text = File_view.Doc.text doc in
  let owned = owned_names item doc_text in
  let spans =
    match (leading_code_span doc_text, code_spans doc_text) with
    | Some leading, first :: rest when trim leading = first -> rest
    | _, spans -> spans
  in
  spans
  |> List.filter_map (fun reference ->
      if String_set.mem reference owned || String_set.mem reference predefined
      then None
      else
        match resolve index scope reference with
        | None -> None
        | Some target ->
            Some
              (Issue.v ~loc:(File_view.Doc.loc doc)
                 {
                   documented_name = File_view.Item.name item;
                   reference;
                   target;
                   location = File_view.Doc.loc doc;
                 }))

let rec check_items index scope items =
  items
  |> List.concat_map (fun item ->
      let here =
        match File_view.Item.doc item with
        | None -> []
        | Some doc -> check_doc index scope item doc
      in
      let component : component =
        { name = File_view.Item.name item; kind = File_view.Item.kind item }
      in
      here
      @ check_items index (enter scope component) (File_view.Item.children item))

let check (ctx : Context.file) =
  if not (File_kind.is_mli (Context.filename ctx)) then []
  else
    let items = File_view.items (Context.view ctx) in
    check_items (index items) root_scope items

let pp ppf { documented_name; reference; target; location = _ } =
  Fmt.pf ppf
    "Documentation for '%s' mentions exported %s [%s]; use odoc link %s"
    documented_name
    (kind_name (target_kind target))
    reference (link target)

let rule =
  Rule.v ~code:"E420" ~title:"Missing Odoc Cross-Reference Link"
    ~category:Documentation
    ~hint:
      "When documentation mentions another exported API item, use an odoc \
       cross-reference link such as {!type-t}, {!val-v}, {!module-M}, \
       {!module-type-S}, {!exception-E}, {!extension-X}, {!constructor-C}, \
       {!field-f}, {!class-c}, {!class-type-c}, {!method-m}, or \
       {!instance-variable-v}. Keep [x] for code literals and documented \
       arguments."
    ~examples:[] ~pp (File check)
