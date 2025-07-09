let to_snake_case name =
  let rec convert acc = function
    | [] -> String.concat "_" (List.rev acc)
    | c :: rest when c >= 'A' && c <= 'Z' ->
        if acc = [] then convert [ String.make 1 (Char.lowercase_ascii c) ] rest
        else convert (String.make 1 (Char.lowercase_ascii c) :: acc) rest
    | c :: rest -> (
        let ch = String.make 1 c in
        match acc with
        | [] -> convert [ ch ] rest
        | h :: t -> convert ((h ^ ch) :: t) rest)
  in
  convert [] (String.to_seq name |> List.of_seq)

let check_variant_name name =
  (* Variants should use Snake_case like Waiting_for_input *)
  (* Check that each word after underscore is capitalized *)
  let parts = String.split_on_char '_' name in
  let is_valid =
    List.for_all
      (fun part -> String.length part > 0 && part.[0] >= 'A' && part.[0] <= 'Z')
      parts
  in
  if not is_valid then
    let expected =
      List.map
        (fun part ->
          if String.length part > 0 then
            String.capitalize_ascii (String.lowercase_ascii part)
          else part)
        parts
      |> String.concat "_"
    in
    Some expected
  else None

let check_value_name name =
  let expected = to_snake_case name in
  if name <> expected && name <> String.lowercase_ascii name then Some expected
  else None

let check_module_name name =
  let expected = to_snake_case name in
  if name <> expected then Some expected else None

let extract_location_from_parsetree text =
  (* Extract location from parsetree text like:
     "Ppat_var "convert" (bad_style.ml[2,27+4]..[2,27+11])"
  *)
  let location_regex =
    Re.compile
      (Re.seq
         [
           Re.str "(";
           Re.group (Re.rep1 Re.alnum);
           (* filename *)
           Re.str "[";
           Re.group (Re.rep1 Re.digit);
           (* line *)
           Re.str ",";
           Re.rep Re.digit;
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

let check_variant_in_parsetree filename text =
  (* Look for Ppat_construct "VariantName" in parsetree text *)
  let variant_regex =
    Re.compile
      (Re.seq
         [
           Re.str "Ppat_construct ";
           Re.str "\"";
           Re.group (Re.rep1 (Re.compl [ Re.char '"' ]));
           Re.str "\"";
         ])
  in
  try
    let substrings = Re.exec_opt variant_regex text in
    match substrings with
    | Some substrings -> (
        let name = Re.Group.get substrings 1 in
        match
          (check_variant_name name, extract_location_from_parsetree text)
        with
        | Some expected, Some (line, col) ->
            Some
              (Violation.Bad_variant_naming
                 {
                   variant = name;
                   location = { file = filename; line; col };
                   expected;
                 })
        | _ -> None)
    | None -> None
  with _ -> None

let check_value_in_parsetree filename text =
  (* Look for Ppat_var "valueName" in parsetree text *)
  let value_regex =
    Re.compile
      (Re.seq
         [
           Re.str "Ppat_var ";
           Re.str "\"";
           Re.group (Re.rep1 (Re.compl [ Re.char '"' ]));
           Re.str "\"";
         ])
  in
  try
    let substrings = Re.exec_opt value_regex text in
    match substrings with
    | Some substrings -> (
        let name = Re.Group.get substrings 1 in
        match (check_value_name name, extract_location_from_parsetree text) with
        | Some expected, Some (line, col) ->
            Some
              (Violation.Bad_value_naming
                 {
                   value_name = name;
                   location = { file = filename; line; col };
                   expected;
                 })
        | _ -> None)
    | None -> None
  with _ -> None

let check_module_in_parsetree filename text =
  (* Look for Pstr_module "ModuleName" in parsetree text *)
  let module_regex =
    Re.compile
      (Re.seq
         [
           Re.str "Pstr_module";
           Re.rep Re.space;
           Re.str "\"";
           Re.group (Re.rep1 (Re.compl [ Re.char '"' ]));
           Re.str "\"";
         ])
  in
  try
    let substrings = Re.exec_opt module_regex text in
    match substrings with
    | Some substrings -> (
        let name = Re.Group.get substrings 1 in
        match
          (check_module_name name, extract_location_from_parsetree text)
        with
        | Some expected, Some (line, col) ->
            Some
              (Violation.Bad_module_naming
                 {
                   module_name = name;
                   location = { file = filename; line; col };
                   expected;
                 })
        | _ -> None)
    | None -> None
  with _ -> None

let check_type_in_parsetree filename text =
  (* Look for type definitions in parsetree text *)
  let type_regex =
    Re.compile
      (Re.seq
         [
           Re.str "type ";
           Re.group (Re.rep1 (Re.compl [ Re.char ' ' ]));
           Re.str " =";
         ])
  in
  try
    let substrings = Re.exec_opt type_regex text in
    match substrings with
    | Some substrings ->
        let name = Re.Group.get substrings 1 in
        if name <> "t" && name <> "id" then
          let is_snake = name = to_snake_case name in
          if not is_snake then
            match extract_location_from_parsetree text with
            | Some (line, col) ->
                Some
                  (Violation.Bad_type_naming
                     {
                       type_name = name;
                       location = { file = filename; line; col };
                       message = "should use snake_case";
                     })
            | None -> None
          else None
        else None
    | None -> None
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

let check_parsetree_line filename text =
  let violations = [] in

  (* Check for variant names *)
  let violations =
    match check_variant_in_parsetree filename text with
    | Some v -> v :: violations
    | None -> violations
  in

  (* Check for value names *)
  let violations =
    match check_value_in_parsetree filename text with
    | Some v -> v :: violations
    | None -> violations
  in

  (* Check for module names *)
  let violations =
    match check_module_in_parsetree filename text with
    | Some v -> v :: violations
    | None -> violations
  in

  (* Check for type names *)
  let violations =
    match check_type_in_parsetree filename text with
    | Some v -> v :: violations
    | None -> violations
  in

  violations

let check data =
  match data with
  | `String text ->
      (* Split text by lines and check each line *)
      let lines = String.split_on_char '\n' text in
      let filename = extract_filename_from_parsetree text in
      List.fold_left
        (fun acc line ->
          let trimmed = String.trim line in
          if trimmed <> "" then
            let violations = check_parsetree_line filename trimmed in
            violations @ acc
          else acc)
        [] lines
  | `List items ->
      (* This is the old browse format, keep for backward compatibility *)
      List.fold_left
        (fun acc item ->
          match item with
          | `Assoc fields -> (
              match List.assoc_opt "filename" fields with
              | Some (`String _filename) ->
                  (* Use old browse-based logic here if needed *)
                  acc
              | _ -> acc)
          | _ -> acc)
        [] items
  | _ -> []
