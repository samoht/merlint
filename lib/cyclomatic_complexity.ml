type config = {
  max_complexity : int;
  max_function_length : int;
}

let default_config = {
  max_complexity = 10;
  max_function_length = 50;
}

type location = {
  file : string;
  line : int;
  col : int;
}

type violation = 
  | ComplexityExceeded of {
      name : string;
      location : location;
      complexity : int;
      threshold : int;
    }
  | FunctionTooLong of {
      name : string;
      location : location;
      length : int;
      threshold : int;
    }

(* Extract location from browse JSON node *)
let extract_location json =
  match json with
  | `Assoc items ->
      let file = match List.assoc_opt "filename" items with
        | Some (`String f) -> f
        | _ -> ""
      in
      let line = match List.assoc_opt "start" items with
        | Some (`Assoc start) ->
            begin match List.assoc_opt "line" start with
            | Some (`Int l) -> l
            | _ -> 0
            end
        | _ -> 0
      in
      let col = match List.assoc_opt "start" items with
        | Some (`Assoc start) ->
            begin match List.assoc_opt "col" start with
            | Some (`Int c) -> c
            | _ -> 0
            end
        | _ -> 0
      in
      { file; line; col }
  | _ -> { file = ""; line = 0; col = 0 }

(* Get the end line from a browse node *)
let get_end_line json =
  match json with
  | `Assoc items ->
      begin match List.assoc_opt "end" items with
      | Some (`Assoc end_) ->
          begin match List.assoc_opt "line" end_ with
          | Some (`Int l) -> l
          | _ -> 0
          end
      | _ -> 0
      end
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
    with _ -> None
  else
    None

(* Count complexity in a browse tree *)
let rec count_complexity_in_node json =
  match json with
  | `Assoc items ->
      let kind = match List.assoc_opt "kind" items with
        | Some (`String k) -> k
        | _ -> ""
      in
      
      (* Base complexity from this node *)
      let node_complexity = 
        if String.contains kind '\n' then
          (* Multi-line kind often contains AST type info *)
          let lines = String.split_on_char '\n' kind in
          List.fold_left (fun acc line ->
            let trimmed = String.trim line in
            if String.starts_with ~prefix:"Texp_ifthenelse" trimmed then acc + 1
            else if String.starts_with ~prefix:"Texp_match" trimmed then acc + 1
            else if String.starts_with ~prefix:"Texp_while" trimmed then acc + 1
            else if String.starts_with ~prefix:"Texp_for" trimmed then acc + 1
            else if String.starts_with ~prefix:"Texp_try" trimmed then acc + 1
            else acc
          ) 0 lines
        else if kind = "case" then
          1  (* Each case in a match adds complexity *)
        else
          0
      in
      
      (* Add complexity from children *)
      let children_complexity = match List.assoc_opt "children" items with
        | Some (`List children) ->
            List.fold_left (fun acc child -> acc + count_complexity_in_node child) 0 children
        | _ -> 0
      in
      
      node_complexity + children_complexity
  | _ -> 0

(* Analyze a value binding node *)
let analyze_value_binding config binding_node =
  match binding_node with
  | `Assoc items ->
      let kind = match List.assoc_opt "kind" items with
        | Some (`String k) -> k
        | _ -> ""
      in
      
      if kind = "value_binding" then
        let children = match List.assoc_opt "children" items with
          | Some (`List c) -> c
          | _ -> []
        in
        
        (* First child should be the pattern with the function name *)
        let name = match children with
          | pattern :: _ ->
              begin match pattern with
              | `Assoc p_items ->
                  begin match List.assoc_opt "kind" p_items with
                  | Some (`String k) -> extract_function_name k
                  | _ -> None
                  end
              | _ -> None
              end
          | _ -> None
        in
        
        match name with
        | Some func_name ->
            let location = extract_location binding_node in
            let end_line = get_end_line binding_node in
            let length = if end_line > location.line then end_line - location.line + 1 else 1 in
            
            (* Count complexity in the entire binding *)
            let complexity = 1 + count_complexity_in_node binding_node in
            
            (* Adjust for match expressions - don't double count *)
            let has_match = ref false in
            let case_count = ref 0 in
            let rec count_cases node =
              match node with
              | `Assoc items ->
                  let kind = match List.assoc_opt "kind" items with
                    | Some (`String k) -> k
                    | _ -> ""
                  in
                  if String.contains kind '\n' then
                    let lines = String.split_on_char '\n' kind in
                    if List.exists (fun l -> String.contains (String.trim l) 'T' && String.starts_with ~prefix:"Texp_match" (String.trim l)) lines then
                      has_match := true;
                  if kind = "case" then
                    incr case_count;
                  begin match List.assoc_opt "children" items with
                  | Some (`List children) -> List.iter count_cases children
                  | _ -> ()
                  end
              | _ -> ()
            in
            count_cases binding_node;
            
            let adjusted_complexity = 
              if !has_match && !case_count > 1 then
                complexity + !case_count - 2  (* -1 for the match, -1 for first case *)
              else
                complexity
            in
            
            let violations = [] in
            let violations = 
              if adjusted_complexity > config.max_complexity then
                ComplexityExceeded {
                  name = func_name;
                  location;
                  complexity = adjusted_complexity;
                  threshold = config.max_complexity;
                } :: violations
              else violations
            in
            let violations =
              if length > config.max_function_length then
                FunctionTooLong {
                  name = func_name;
                  location;
                  length;
                  threshold = config.max_function_length;
                } :: violations
              else violations
            in
            violations
        | None -> []
      else
        []
  | _ -> []

(* Recursively analyze the browse tree *)
let rec analyze_browse_tree config json =
  match json with
  | `Assoc items ->
      let kind = match List.assoc_opt "kind" items with
        | Some (`String k) -> k
        | _ -> ""
      in
      
      (* Check if this is a value binding *)
      let current_violations = 
        if kind = "value_binding" then
          analyze_value_binding config json
        else
          []
      in
      
      (* Recursively check children *)
      let child_violations = match List.assoc_opt "children" items with
        | Some (`List children) ->
            List.concat_map (analyze_browse_tree config) children
        | _ -> []
      in
      
      current_violations @ child_violations
  | _ -> []

let analyze_structure config json =
  match json with
  | `Assoc items ->
      begin match List.assoc_opt "class" items, List.assoc_opt "value" items with
      | Some (`String "return"), Some (`List [browse_tree]) ->
          analyze_browse_tree config browse_tree
      | _ -> []
      end
  | _ -> []

let format_violation = function
  | ComplexityExceeded { name; location; complexity; threshold } ->
      Printf.sprintf "%s:%d:%d: Function '%s' has cyclomatic complexity of %d (threshold: %d)"
        location.file location.line location.col name complexity threshold
  | FunctionTooLong { name; location; length; threshold } ->
      Printf.sprintf "%s:%d:%d: Function '%s' is %d lines long (threshold: %d)"
        location.file location.line location.col name length threshold