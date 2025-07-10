(** OCamlmerlin browse output - for finding value bindings and pattern info *)

type location = Location.extended
type pattern_info = { has_pattern_match : bool; case_count : int }

type value_binding = {
  name : string option;
  location : location option;
  pattern_info : pattern_info;
}

type t = { value_bindings : value_binding list }

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
              (Location.create_extended ~file:filename ~start_line ~start_col
                 ~end_line ~end_col)
          else None
      | _ -> None)
  | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null | `String _ ->
      None

(** Extract variable name from pattern kind string like: "pattern
    (file.ml[1,2+3]..file.ml[1,2+4])\n Tpat_var \"name/123\"" *)
let extract_var_name kind_str =
  match Astring.String.find_sub ~sub:"Tpat_var \"" kind_str with
  | Some idx -> (
      let after_var =
        Astring.String.with_index_range ~first:(idx + 10) kind_str
      in
      match Astring.String.cut ~sep:"\"" after_var with
      | Some (name, _) -> (
          (* Remove /uid suffix if present *)
          match Astring.String.cut ~sep:"/" name with
          | Some (n, _) -> Some n
          | None -> Some name)
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

(** Extract value binding info from a value_binding node *)
let extract_value_binding (json : Yojson.Safe.t) =
  match json with
  | `Assoc items
    when match List.assoc_opt "kind" items with
         | Some (`String "value_binding") -> true
         | _ -> false ->
      (* Look for the pattern child to get the name *)
      let name =
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
      let location = extract_location json in
      let pattern_info =
        { has_pattern_match = has_cases json; case_count = count_cases json }
      in
      Some { name; location; pattern_info }
  | _ -> None

(** Find all value bindings in the tree *)
let rec find_value_bindings (json : Yojson.Safe.t) =
  match json with
  | `Assoc items ->
      let current = extract_value_binding json |> Option.to_list in
      let children_bindings =
        match List.assoc_opt "children" items with
        | Some (`List children) -> List.concat_map find_value_bindings children
        | _ -> []
      in
      current @ children_bindings
  | _ -> []

(** Parse browse output *)
let of_json (json : Yojson.Safe.t) : t =
  match json with
  | `List [ tree ] -> { value_bindings = find_value_bindings tree }
  | _ -> { value_bindings = [] }

(** Get all value bindings *)
let get_value_bindings t = t.value_bindings
