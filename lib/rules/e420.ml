(** E420: Missing Odoc Cross-Reference Links *)

module String_map = Map.Make (String)
module String_set = Set.Make (String)

type component = { name : string; kind : File_view.Item.kind }
type target = { name : string; path : component list }

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
  | _ -> String.concat "." (List.map (fun c -> c.name) prefix @ [ name ])

let target_kind target =
  match List.rev target.path with
  | [] -> File_view.Item.Value
  | last :: _ -> last.kind

let rec add_item (prefix : component list) acc item =
  let name = File_view.Item.name item in
  let kind = File_view.Item.kind item in
  let path = name_path prefix name in
  let component : component = { name; kind } in
  let target = { name = path; path = prefix @ [ component ] } in
  let acc = String_map.add path target acc in
  let acc =
    match prefix with
    | [] -> String_map.add name target acc
    | _ -> (
        match List.rev target.path with
        | [ _ ] | [] -> acc
        | last :: _ -> String_map.add name { target with path = [ last ] } acc)
  in
  List.fold_left
    (add_item (target.path))
    acc
    (File_view.Item.children item)

let targets items = List.fold_left (add_item []) String_map.empty items
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

let prefix_names item doc =
  let self = File_view.Item.name item in
  match leading_code_span doc with
  | None -> String_set.singleton self
  | Some span -> (
      match words span with
      | [] -> String_set.singleton self
      | name :: args when name = self ->
          args |> List.map unlabel
          |> List.fold_left
               (fun names arg -> String_set.add arg names)
               (String_set.singleton self)
      | _ -> String_set.singleton self)

let find_from s start pattern =
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
        match find_from doc (i + 2) "]}" with
        | Some stop -> stop + 2
        | None -> len
      in
      loop acc next
    else if i + 1 < len && doc.[i] = '{' && doc.[i + 1] = 'v' then
      let next =
        match find_from doc (i + 2) "v}" with
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

let check_doc target_map item doc =
  let doc_text = File_view.Doc.text doc in
  let ignored = prefix_names item doc_text in
  let spans =
    match (leading_code_span doc_text, code_spans doc_text) with
    | Some leading, first :: rest when trim leading = first -> rest
    | _, spans -> spans
  in
  spans
  |> List.filter_map (fun reference ->
      if String_set.mem reference ignored then None
      else
        match String_map.find_opt reference target_map with
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

let check_item target_map item =
  match File_view.Item.doc item with
  | None -> []
  | Some doc -> check_doc target_map item doc

let check (ctx : Context.file) =
  if not (File_kind.is_mli ctx.filename) then []
  else
    let items = File_view.all_items (Context.view ctx) in
    let target_map = targets items in
    List.concat_map (check_item target_map) items

let pp ppf { documented_name; reference; target; location = _ } =
  Fmt.pf ppf
    "Documentation for '%s' mentions exported %s [%s]; use odoc link %s"
    documented_name (kind_name (target_kind target)) reference (link target)

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
