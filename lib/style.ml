(* Extract location from parsetree text *)
let extract_location_from_parsetree text =
  let location_regex =
    Re.compile
      (Re.seq
         [
           Re.str "(";
           Re.group (Re.rep1 (Re.compl [ Re.char '[' ]));
           Re.str "[";
           Re.group (Re.rep1 Re.digit);
           Re.str ",";
           Re.rep1 Re.digit;
           Re.str "+";
           Re.group (Re.rep1 Re.digit);
           Re.str "]";
         ])
  in
  try
    let substrings = Re.exec location_regex text in
    let line = int_of_string (Re.Group.get substrings 2) in
    let col = int_of_string (Re.Group.get substrings 3) in
    Some (line, col)
  with Not_found -> None

let extract_filename_from_parsetree text =
  let filename_regex =
    Re.compile
      (Re.seq
         [
           Re.str "("; Re.group (Re.rep1 (Re.compl [ Re.char '[' ])); Re.str "[";
         ])
  in
  try
    let substrings = Re.exec filename_regex text in
    Re.Group.get substrings 1
  with Not_found -> "unknown"

(* Extract location from match position by searching backwards *)
let extract_location_from_match text pos =
  (* Look backwards from pos to find the location *)
  let rec find_location_backwards i =
    if i < 0 then None
    else if i + 1 < String.length text && text.[i] = '(' then
      (* Found a potential location start *)
      let location_end =
        try String.index_from text i ']' with Not_found -> -1
      in
      if location_end > i then
        let location_str = String.sub text i (location_end - i + 1) in
        extract_location_from_parsetree location_str
      else find_location_backwards (i - 1)
    else find_location_backwards (i - 1)
  in

  (* Also look forward from pos to find the location *)
  let rec find_location_forward i =
    if i >= String.length text then None
    else if text.[i] = '(' then
      (* Found a potential location start *)
      let location_end =
        try String.index_from text i ']' with Not_found -> -1
      in
      if location_end > i then
        let location_str = String.sub text i (location_end - i + 1) in
        extract_location_from_parsetree location_str
      else find_location_forward (i + 1)
    else find_location_forward (i + 1)
  in

  (* Try backwards first, then forward *)
  match find_location_backwards (min pos (String.length text - 1)) with
  | Some loc -> Some loc
  | None -> find_location_forward pos

(* Extract location for a specific line containing text *)
let extract_location_near text search_text =
  try
    let pos = Re.(exec_opt (compile (str search_text)) text) in
    match pos with
    | Some m -> extract_location_from_match text (Re.Group.start m 0)
    | None -> None
  with Not_found -> None

let check_obj_magic filename text =
  if String.contains text 'O' && String.contains text 'm' then
    let magic_regex = Re.compile (Re.str "Pexp_ident \"Obj.magic\"") in
    let matches = Re.all ~pos:0 magic_regex text in
    List.fold_left
      (fun acc group ->
        let start_pos = Re.Group.start group 0 in
        match extract_location_from_match text start_pos with
        | Some (line, col) ->
            Issue.No_obj_magic { location = { file = filename; line; col } }
            :: acc
        | None -> acc)
      [] matches
  else []

let check_str_module filename text =
  if String.contains text 'S' && String.contains text 't' then
    let str_regex = Re.compile (Re.str "Pexp_ident \"Str.") in
    let matches = Re.all ~pos:0 str_regex text in
    List.fold_left
      (fun acc group ->
        let start_pos = Re.Group.start group 0 in
        match extract_location_from_match text start_pos with
        | Some (line, col) ->
            Issue.Use_str_module { location = { file = filename; line; col } }
            :: acc
        | None -> acc)
      [] matches
  else []

let is_catch_all_pattern pattern =
  match pattern with
  | `Assoc fields -> (
      match List.assoc_opt "class" fields with
      | Some (`String "Ppat_any") -> true
      | Some (`String "Ppat_var") -> (
          (* Check if it's _something which is also a catch-all *)
          match List.assoc_opt "name" fields with
          | Some (`String name) -> String.starts_with ~prefix:"_" name
          | _ -> false)
      | _ -> false)
  | _ -> false

let extract_location_from_fields fields =
  match List.assoc_opt "location" fields with
  | Some (`Assoc loc_fields) -> (
      match
        ( List.assoc_opt "start" loc_fields,
          List.assoc_opt "line" loc_fields,
          List.assoc_opt "col" loc_fields )
      with
      | Some (`Int line), _, Some (`Int col)
      | _, Some (`Int line), Some (`Int col) ->
          Some (line, col)
      | _ -> None)
  | _ -> None

let check_exception_case filename fields case =
  match case with
  | `Assoc case_fields -> (
      match List.assoc_opt "pattern" case_fields with
      | Some pattern when is_catch_all_pattern pattern -> (
          match extract_location_from_fields fields with
          | Some (line, col) ->
              [
                Issue.Catch_all_exception
                  { location = { file = filename; line; col } };
              ]
          | None -> [])
      | _ -> [])
  | _ -> []

let check_try_expression filename fields =
  match List.assoc_opt "exceptions" fields with
  | Some (`List cases) ->
      List.fold_left
        (fun acc case -> acc @ check_exception_case filename fields case)
        [] cases
  | _ -> []

(* Parse JSON AST to check for catch-all exceptions *)
let rec check_json_catch_all filename json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "class" fields with
      | Some (`String "Pexp_try") -> check_try_expression filename fields
      | _ ->
          List.fold_left
            (fun acc (_, child) -> acc @ check_json_catch_all filename child)
            [] fields)
  | `List items ->
      List.fold_left
        (fun acc item -> acc @ check_json_catch_all filename item)
        [] items
  | _ -> []

(* Simple text-based check for catch-all - fallback *)
let check_catch_all_text filename text =
  (* Look for patterns like "with _ ->" or "with _e ->" in try blocks *)
  let catch_all_regex =
    Re.compile
      (Re.seq
         [
           Re.str "with";
           Re.rep1 Re.space;
           Re.group
             (Re.alt
                [
                  Re.str "_";
                  (* Just underscore *)
                  Re.seq [ Re.str "_"; Re.rep1 Re.alnum ] (* _variable *);
                ]);
           Re.rep Re.space;
           Re.str "->";
         ])
  in

  (* Also check if we're in a try context *)
  if Re.execp (Re.compile (Re.str "try")) text then
    let matches = Re.all ~pos:0 catch_all_regex text in
    List.fold_left
      (fun acc _m ->
        match extract_location_near text "try" with
        | Some (line, col) ->
            Issue.Catch_all_exception
              { location = { file = filename; line; col } }
            :: acc
        | None -> acc)
      [] matches
  else []

let check_printf_module filename text =
  let printf_regex = Re.compile (Re.str "Pexp_ident \"Printf.") in
  let format_regex = Re.compile (Re.str "Pexp_ident \"Format.") in

  let check_module regex module_name =
    if Re.execp regex text then
      let matches = Re.all ~pos:0 regex text in
      List.fold_left
        (fun acc group ->
          let start_pos = Re.Group.start group 0 in
          match extract_location_from_match text start_pos with
          | Some (line, col) ->
              Issue.Use_printf_module
                {
                  location = { file = filename; line; col };
                  module_used = module_name;
                }
              :: acc
          | None -> acc)
        [] matches
    else []
  in

  check_module printf_regex "Printf" @ check_module format_regex "Format"

let check parsetree_data =
  match parsetree_data with
  | `String text ->
      let filename = extract_filename_from_parsetree text in
      let obj_magic_issues = check_obj_magic filename text in
      let str_module_issues = check_str_module filename text in
      let printf_module_issues = check_printf_module filename text in

      (* For catch-all, try the simple text-based approach *)
      let catch_all_issues = check_catch_all_text filename text in

      obj_magic_issues @ str_module_issues @ printf_module_issues
      @ catch_all_issues
  | json ->
      (* If we get JSON, use the proper parser *)
      let filename = "unknown" in
      (* TODO: extract from JSON *)
      check_json_catch_all filename json
