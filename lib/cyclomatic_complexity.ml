type config = {
  max_complexity : int;
  max_function_length : int;
  max_nesting : int;
}

let default_config =
  { max_complexity = 10; max_function_length = 50; max_nesting = 3 }

(* Extract filename from JSON *)
let extract_filename items =
  match List.assoc_opt "filename" items with Some (`String f) -> f | _ -> ""

(* Extract integer field from a JSON object *)
let extract_int_field (obj : Yojson.Safe.t) field_name =
  match obj with
  | `Assoc fields -> (
      match List.assoc_opt field_name fields with Some (`Int n) -> n | _ -> 0)
  | _ -> 0

(* Extract start position from JSON *)
let extract_start_position items field_name =
  match List.assoc_opt "start" items with
  | Some start -> extract_int_field start field_name
  | _ -> 0

(* Extract location from browse JSON node *)
let extract_location (json : Yojson.Safe.t) =
  match json with
  | `Assoc items ->
      {
        Issue.file = extract_filename items;
        line = extract_start_position items "line";
        col = extract_start_position items "col";
      }
  | _ -> { file = ""; line = 0; col = 0 }

(* Get the end line from a browse node *)
let get_end_line (json : Yojson.Safe.t) =
  match json with
  | `Assoc items -> (
      match List.assoc_opt "end" items with
      | Some end_pos -> extract_int_field end_pos "line"
      | _ -> 0)
  | _ -> 0

(* Extract function name from pattern kind string *)
let extract_function_name kind_str =
  (* Look for pattern like: "pattern (file.ml[1,2+3]..file.ml[1,2+4])\n  Tpat_var \"name/123\"" *)
  if String.contains kind_str '"' then
    try
      let quote1 = String.index kind_str '"' in
      let quote2 = String.index_from kind_str (quote1 + 1) '"' in
      let full_name = String.sub kind_str (quote1 + 1) (quote2 - quote1 - 1) in
      (* Remove /number suffix *)
      match String.index_opt full_name '/' with
      | Some idx -> Some (String.sub full_name 0 idx)
      | None -> Some full_name
    with Invalid_argument _ | Not_found -> None
  else None

(* Count complexity in a browse tree *)
let rec count_complexity_in_node (json : Yojson.Safe.t) =
  match json with
  | `Assoc items ->
      let kind =
        match List.assoc_opt "kind" items with Some (`String k) -> k | _ -> ""
      in

      (* Base complexity from this node *)
      let node_complexity =
        if String.contains kind '\n' then
          (* Multi-line kind often contains AST type info *)
          let lines = String.split_on_char '\n' kind in
          List.fold_left
            (fun acc line ->
              let trimmed = String.trim line in
              if String.starts_with ~prefix:"Texp_ifthenelse" trimmed then
                acc + 1
              else if String.starts_with ~prefix:"Texp_match" trimmed then
                acc + 1
              else if String.starts_with ~prefix:"Texp_while" trimmed then
                acc + 1
              else if String.starts_with ~prefix:"Texp_for" trimmed then acc + 1
              else if String.starts_with ~prefix:"Texp_try" trimmed then acc + 1
              else acc)
            0 lines
        else if kind = "case" then 1 (* Each case in a match adds complexity *)
        else 0
      in

      (* Add complexity from children *)
      let children_complexity =
        match List.assoc_opt "children" items with
        | Some (`List children) ->
            List.fold_left
              (fun acc child -> acc + count_complexity_in_node child)
              0 children
        | _ -> 0
      in

      node_complexity + children_complexity
  | _ -> 0

(* Extract function name from the first child of a value binding *)
let extract_child_function_name children =
  match children with
  | pattern :: _ -> (
      match pattern with
      | `Assoc p_items -> (
          match List.assoc_opt "kind" p_items with
          | Some (`String k) -> extract_function_name k
          | _ -> None)
      | _ -> None)
  | _ -> None

(* Count match cases in a node for complexity adjustment *)
let count_match_cases (node : Yojson.Safe.t) =
  let has_match = ref false in
  let case_count = ref 0 in
  let rec count_cases node =
    match node with
    | `Assoc items ->
        let kind =
          match List.assoc_opt "kind" items with
          | Some (`String k) -> k
          | _ -> ""
        in
        if String.contains kind '\n' then (
          let lines = String.split_on_char '\n' kind in
          if
            List.exists
              (fun l ->
                String.contains (String.trim l) 'T'
                && String.starts_with ~prefix:"Texp_match" (String.trim l))
              lines
          then has_match := true;
          if kind = "case" then incr case_count;
          match List.assoc_opt "children" items with
          | Some (`List children) -> List.iter count_cases children
          | _ -> ())
    | _ -> ()
  in
  count_cases node;
  (!has_match, !case_count)

(* Calculate function length *)
let calculate_function_length location end_line =
  if end_line > location.Issue.line then end_line - location.Issue.line + 1
  else 1

(* Calculate nesting depth *)
let rec calculate_nesting_depth (json : Yojson.Safe.t) =
  match json with
  | `Assoc items ->
      let kind =
        match List.assoc_opt "kind" items with Some (`String k) -> k | _ -> ""
      in
      let lines =
        if String.contains kind '\n' then String.split_on_char '\n' kind
        else [ kind ]
      in
      let is_nesting_node =
        List.exists
          (fun line ->
            let trimmed = String.trim line in
            String.starts_with ~prefix:"Texp_ifthenelse" trimmed
            || String.starts_with ~prefix:"Texp_match" trimmed
            || String.starts_with ~prefix:"Texp_while" trimmed
            || String.starts_with ~prefix:"Texp_for" trimmed
            || String.starts_with ~prefix:"Texp_try" trimmed)
          lines
      in
      let children_depth =
        match List.assoc_opt "children" items with
        | Some (`List children) ->
            List.fold_left
              (fun acc child -> max acc (calculate_nesting_depth child))
              0 children
        | _ -> 0
      in
      if is_nesting_node then 1 + children_depth else children_depth
  | _ -> 0

(* Create issues based on thresholds *)
let create_issues config func_name location complexity length nesting =
  let issues = [] in
  let issues =
    if complexity > config.max_complexity then
      Issue.Complexity_exceeded
        {
          name = func_name;
          location;
          complexity;
          threshold = config.max_complexity;
        }
      :: issues
    else issues
  in
  let issues =
    if length > config.max_function_length then
      Issue.Function_too_long
        {
          name = func_name;
          location;
          length;
          threshold = config.max_function_length;
        }
      :: issues
    else issues
  in
  let issues =
    if nesting > config.max_nesting then
      Issue.Deep_nesting
        {
          name = func_name;
          location;
          depth = nesting;
          threshold = config.max_nesting;
        }
      :: issues
    else issues
  in
  issues

(* Analyze a value binding node *)
let analyze_value_binding config (binding_node : Yojson.Safe.t) =
  match[@warning "-8-11"] binding_node with
  | `Assoc items -> (
      let kind =
        match List.assoc_opt "kind" items with Some (`String k) -> k | _ -> ""
      in

      if kind <> "value_binding" then []
      else
        let children =
          match List.assoc_opt "children" items with
          | Some (`List c) -> c
          | _ -> []
        in

        match extract_child_function_name children with
        | None -> []
        | Some func_name ->
            let location = extract_location binding_node in
            let end_line = get_end_line binding_node in
            let length = calculate_function_length location end_line in

            (* Count complexity *)
            let base_complexity = 1 + count_complexity_in_node binding_node in

            (* Adjust for match expressions *)
            let has_match, case_count = count_match_cases binding_node in
            let adjusted_complexity =
              if has_match && case_count > 1 then
                base_complexity + case_count - 2
              else base_complexity
            in

            let nesting = calculate_nesting_depth binding_node in
            create_issues config func_name location adjusted_complexity
              length nesting
        | _ -> [])

(* Recursively analyze the browse tree *)
let rec analyze_browse_tree config (json : Yojson.Safe.t) =
  match json with
  | `Assoc items ->
      let kind =
        match List.assoc_opt "kind" items with Some (`String k) -> k | _ -> ""
      in

      (* Check if this is a value binding *)
      let current_issues =
        if kind = "value_binding" then analyze_value_binding config json else []
      in

      (* Recursively check children *)
      let child_issues =
        match List.assoc_opt "children" items with
        | Some (`List children) ->
            List.concat_map (analyze_browse_tree config) children
        | _ -> []
      in

      current_issues @ child_issues
  | _ -> []

let analyze_browse_value config (json : Yojson.Safe.t) =
  match json with
  | `List [ browse_tree ] -> analyze_browse_tree config browse_tree
  | _ -> []
