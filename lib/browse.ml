(** OCamlmerlin browse output - for finding value bindings and pattern info *)

type pattern_info = { has_pattern_match : bool; case_count : int }

type value_binding = {
  ast_elt : Ast.elt;
  pattern_info : pattern_info;
  is_function : bool;
  is_simple_list : bool;
}

type t = { value_bindings : value_binding list }

let empty () = { value_bindings = [] }

(** Extract location from JSON node *)
let extract_location (json : Yojson.Safe.t) =
  match json with
  | `Assoc items -> (
      let extract_pos pos field =
        match pos with
        | `Assoc fields -> (
            match List.assoc_opt field fields with Some (`Int n) -> n | _ -> 0)
        | _ -> 0
      in
      let filename =
        match List.assoc_opt "filename" items with
        | Some (`String f) -> f
        | _ -> ""
      in
      let start_pos = List.assoc_opt "start" items in
      let end_pos = List.assoc_opt "end" items in
      match (start_pos, end_pos) with
      | Some start, Some end_p ->
          let start_line = extract_pos start "line" in
          let start_col = extract_pos start "col" in
          let end_line = extract_pos end_p "line" in
          let end_col = extract_pos end_p "col" in
          if filename <> "" && start_line > 0 then
            Some
              (Location.create ~file:filename ~start_line ~start_col ~end_line
                 ~end_col)
          else None
      | _ -> None)
  | _ -> None

(** Extract variable name from pattern kind string like: "pattern
    (file.ml[1,2+3]..file.ml[1,2+4])\n Tpat_var \"name/123\"" *)
let extract_var_name kind_str =
  match Astring.String.find_sub ~sub:"Tpat_var \"" kind_str with
  | Some idx -> (
      let after_var =
        Astring.String.with_index_range ~first:(idx + 10) kind_str
      in
      match Ast.extract_quoted_string after_var with
      | Some name_str ->
          Some (Ast.parse_name ~handle_bang_suffix:false name_str)
      | None -> None)
  | None -> None

(** Count case nodes in children *)
let rec count_cases json =
  match json with
  | `Assoc items ->
      let is_case =
        match List.assoc_opt "kind" items with
        | Some (`String "case") -> 1
        | _ -> 0
      in
      let children_cases =
        match List.assoc_opt "children" items with
        | Some (`List children) ->
            List.fold_left (fun acc child -> acc + count_cases child) 0 children
        | _ -> 0
      in
      is_case + children_cases
  | _ -> 0

(** Check if node or children contain cases (indicating pattern matching) *)
let has_cases json = count_cases json > 0

(** Check if an expression node represents a function (has pattern children) *)
let is_function_expr json =
  match json with
  | `Assoc items -> (
      match List.assoc_opt "kind" items with
      | Some (`String "expression") -> (
          match List.assoc_opt "children" items with
          | Some (`List children) ->
              List.exists
                (fun child ->
                  match child with
                  | `Assoc child_items -> (
                      match List.assoc_opt "kind" child_items with
                      | Some (`String kind) ->
                          Astring.String.is_prefix ~affix:"pattern" kind
                      | _ -> false)
                  | _ -> false)
                children
          | _ -> false)
      | _ -> false)
  | _ -> false

(** Check if a kind string represents a field-related construct *)
let is_field_kind kind =
  match kind with
  | "field" -> true
  | "record_field" -> true
  | kind when String.length kind > 0 && kind.[0] = '(' ->
      (* Check for patterns like "(field ...)" or "Texp_field" *)
      kind = "(field)"
      || Astring.String.is_prefix ~affix:"(field " kind
      || Astring.String.is_infix ~affix:"Texp_field" kind
  | _ -> false

(** Check if an expression is a simple data structure (list or record) *)
let is_data_structure_expr json =
  (* A data structure is characterized by:
     - List: having only expression children
     - Record: having field children or being a record expression *)
  match json with
  | `Assoc items -> (
      match List.assoc_opt "kind" items with
      | Some (`String "expression") -> (
          match List.assoc_opt "children" items with
          | Some (`List children) ->
              (* Check if all children are either expressions (list) or fields (record) *)
              List.for_all
                (fun child ->
                  match child with
                  | `Assoc child_items -> (
                      match List.assoc_opt "kind" child_items with
                      | Some (`String "expression") -> true
                      | Some (`String "field") -> true
                      | Some (`String kind) -> is_field_kind kind
                      | _ -> false)
                  | _ -> false)
                children
          | _ -> true (* No children means it's a simple value like [] or {} *))
      | _ -> false)
  | _ -> false

(** Extract value binding info from a value_binding node *)
let extract_value_binding (json : Yojson.Safe.t) =
  match json with
  | `Assoc items
    when match List.assoc_opt "kind" items with
         | Some (`String "value_binding") -> true
         | _ -> false ->
      (* Look for the pattern child to get the name *)
      let name_opt =
        match List.assoc_opt "children" items with
        | Some (`List children) ->
            List.find_map
              (fun child ->
                match child with
                | `Assoc child_items -> (
                    match List.assoc_opt "kind" child_items with
                    | Some (`String kind)
                      when Astring.String.is_prefix ~affix:"pattern" kind ->
                        extract_var_name kind
                    | _ -> None)
                | _ -> None)
              children
        | _ -> None
      in
      let location_opt = extract_location json in

      let ast_elt =
        let name =
          Option.value
            ~default:(Ast.parse_name ~handle_bang_suffix:false "")
            name_opt
        in
        { Ast.name; location = location_opt }
      in

      let pattern_info =
        { has_pattern_match = has_cases json; case_count = count_cases json }
      in

      (* Check if this is a function or a simple data structure *)
      let is_function, is_simple_list =
        match List.assoc_opt "children" items with
        | Some (`List children) -> (
            (* Find the expression child (second child typically) *)
            let expr_child =
              List.find_opt
                (fun child ->
                  match child with
                  | `Assoc child_items -> (
                      match List.assoc_opt "kind" child_items with
                      | Some (`String "expression") -> true
                      | _ -> false)
                  | _ -> false)
                children
            in
            match expr_child with
            | Some expr ->
                ( is_function_expr expr,
                  if is_function_expr expr then false
                  else is_data_structure_expr expr )
            | None -> (false, false))
        | _ -> (false, false)
      in

      Some { ast_elt; pattern_info; is_function; is_simple_list }
  | _ -> None

(** Get all value bindings in the tree *)
let rec get_value_bindings (json : Yojson.Safe.t) =
  match json with
  | `Assoc items ->
      let current = extract_value_binding json |> Option.to_list in
      let children_bindings =
        match List.assoc_opt "children" items with
        | Some (`List children) -> List.concat_map get_value_bindings children
        | _ -> []
      in
      current @ children_bindings
  | _ -> []

(** Parse browse output *)
let of_json (json : Yojson.Safe.t) : t =
  match json with
  | `List [ tree ] -> { value_bindings = get_value_bindings tree }
  | _ -> { value_bindings = [] }

(** Get all value bindings *)
let get_value_bindings t = t.value_bindings
