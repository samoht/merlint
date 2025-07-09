let extract_location_from_parsetree text =
  (* Extract location from parsetree text like:
     "Pexp_ident "Obj.magic" (bad_style.ml[2,27+16]..[2,27+25])"
  *)
  let location_regex =
    Re.compile
      (Re.seq
         [
           Re.str "(";
           Re.group (Re.rep1 (Re.compl [ Re.char '[' ]));
           (* filename *)
           Re.str "[";
           Re.group (Re.rep1 Re.digit);
           (* line *)
           Re.str ",";
           Re.rep1 Re.digit;
           (* offset *)
           Re.str "+";
           Re.group (Re.rep1 Re.digit);
           (* col *)
           Re.str "]";
         ])
  in
  try
    let substrings = Re.exec location_regex text in
    let line = int_of_string (Re.Group.get substrings 2) in
    let col = int_of_string (Re.Group.get substrings 3) in
    Some (line, col)
  with _ -> None

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
  with _ -> "unknown"

let extract_location_from_match text start_pos =
  (* Extract location from a specific match position in parsetree text *)
  let substring = String.sub text start_pos (String.length text - start_pos) in
  let location_regex =
    Re.compile
      (Re.seq
         [
           Re.str "(";
           Re.group (Re.rep1 (Re.compl [ Re.char '[' ]));
           (* filename *)
           Re.str "[";
           Re.group (Re.rep1 Re.digit);
           (* line *)
           Re.str ",";
           Re.rep1 Re.digit;
           (* offset *)
           Re.str "+";
           Re.group (Re.rep1 Re.digit);
           (* col *)
           Re.str "]";
         ])
  in
  try
    let substrings = Re.exec location_regex substring in
    let line = int_of_string (Re.Group.get substrings 2) in
    let col = int_of_string (Re.Group.get substrings 3) in
    Some (line, col)
  with _ -> None

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

let check_catch_all filename text =
  if String.contains text 'P' && String.contains text 't' then
    let try_regex = Re.compile (Re.str "Pexp_try") in
    let any_regex = Re.compile (Re.str "Ppat_any") in
    if Re.execp try_regex text && Re.execp any_regex text then
      (* For catch-all, we want the location of the try expression *)
      match Re.exec_opt try_regex text with
      | Some substrings -> (
          let try_pos = Re.Group.start substrings 0 in
          match extract_location_from_match text try_pos with
          | Some (line, col) ->
              [
                Issue.Catch_all_exception
                  { location = { file = filename; line; col } };
              ]
          | None -> [])
      | None -> []
    else []
  else []

let check parsetree_data =
  match parsetree_data with
  | `String text ->
      let filename = extract_filename_from_parsetree text in
      let obj_magic_issues = check_obj_magic filename text in
      let str_module_issues = check_str_module filename text in
      let catch_all_issues = check_catch_all filename text in
      obj_magic_issues @ str_module_issues @ catch_all_issues
  | _ -> []
