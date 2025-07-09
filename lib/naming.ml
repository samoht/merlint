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
  (* Variants should start with a capital letter *)
  (* Multi-word variants should use underscores: Missing_mli_doc not MissingMliDoc *)
  if String.length name = 0 then None
  else if name.[0] < 'A' || name.[0] > 'Z' then
    (* Must start with capital *)
    Some (String.capitalize_ascii name)
  else
    (* Check for CamelCase that should use underscores *)
    let has_lowercase_then_uppercase = ref false in
    for i = 0 to String.length name - 2 do
      if
        name.[i] >= 'a'
        && name.[i] <= 'z'
        && name.[i + 1] >= 'A'
        && name.[i + 1] <= 'Z'
      then has_lowercase_then_uppercase := true
    done;

    if !has_lowercase_then_uppercase then (
      (* Convert CamelCase to Snake_case (lowercase after underscore) *)
      let result = ref "" in
      for i = 0 to String.length name - 1 do
        if
          i > 0
          && name.[i] >= 'A'
          && name.[i] <= 'Z'
          && i > 0
          && name.[i - 1] >= 'a'
          && name.[i - 1] <= 'z'
        then
          result :=
            !result ^ "_" ^ String.make 1 (Char.lowercase_ascii name.[i])
        else result := !result ^ String.make 1 name.[i]
      done;
      Some !result)
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
           Re.group (Re.rep1 (Re.compl [ Re.char '[' ]));
           (* filename - may contain dots *)
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
  with Not_found -> None

let check_variant_in_parsetree filename text =
  (* Look for variant names in parsetree text like:
     "WaitingForInput" (bad_names.ml[7,97+14]..[7,97+29])
     These appear in type declarations with quotes around the name *)
  let variant_regex =
    Re.compile
      (Re.seq
         [
           Re.str "\"";
           Re.group (Re.rep1 (Re.compl [ Re.char '"' ]));
           Re.str "\" (";
           Re.group (Re.rep1 (Re.compl [ Re.char '[' ]));
           (* filename *)
           Re.str "[";
         ])
  in
  try
    let matches = Re.all ~pos:0 variant_regex text in
    List.fold_left
      (fun acc group ->
        let name = Re.Group.get group 1 in
        (* Only check names that look like variants (start with uppercase letter A-Z) *)
        if
          String.length name > 0
          && name.[0] >= 'A'
          && name.[0] <= 'Z'
          && String.for_all
               (fun c ->
                 (c >= 'A' && c <= 'Z')
                 || (c >= 'a' && c <= 'z')
                 || (c >= '0' && c <= '9')
                 || c = '_')
               name
        then
          match check_variant_name name with
          | Some expected -> (
              match extract_location_from_parsetree text with
              | Some (line, col) ->
                  Issue.Bad_variant_naming
                    {
                      variant = name;
                      location = { file = filename; line; col };
                      expected;
                    }
                  :: acc
              | None -> acc)
          | None -> acc
        else acc)
      [] matches
  with Not_found -> []

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
    let matches = Re.all ~pos:0 value_regex text in
    List.fold_left
      (fun acc group ->
        let name = Re.Group.get group 1 in
        (* Skip single letter variables and common short names *)
        if String.length name > 1 && name <> "x" && name <> "y" && name <> "v"
        then
          match check_value_name name with
          | Some expected -> (
              match extract_location_from_parsetree text with
              | Some (line, col) ->
                  Issue.Bad_value_naming
                    {
                      value_name = name;
                      location = { file = filename; line; col };
                      expected;
                    }
                  :: acc
              | None -> acc)
          | None -> acc
        else acc)
      [] matches
  with Not_found -> []

let check_module_in_parsetree filename text =
  (* Look for Pstr_module "ModuleName" in parsetree text *)
  let module_regex =
    Re.compile
      (Re.seq
         [
           Re.str "Pstr_module";
           Re.rep1 Re.space;
           Re.str "\"";
           Re.group (Re.rep1 (Re.compl [ Re.char '"' ]));
           Re.str "\"";
         ])
  in
  try
    let matches = Re.all ~pos:0 module_regex text in
    List.fold_left
      (fun acc group ->
        let name = Re.Group.get group 1 in
        match check_module_name name with
        | Some expected -> (
            match extract_location_from_parsetree text with
            | Some (line, col) ->
                Issue.Bad_module_naming
                  {
                    module_name = name;
                    location = { file = filename; line; col };
                    expected;
                  }
                :: acc
            | None -> acc)
        | None -> acc)
      [] matches
  with Not_found -> []

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
                  (Issue.Bad_type_naming
                     {
                       type_name = name;
                       location = { file = filename; line; col };
                       message = "should use snake_case";
                     })
            | None -> None
          else None
        else None
    | None -> None
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

let check_function_naming _filename _text =
  (* TODO: Implement function naming convention checking using merlin outline *)
  (* Temporarily disabled to avoid merlin outline issues in tests *)
  []

let check_long_identifier_name filename text =
  let max_underscores = 3 in
  let identifier_regex =
    Re.compile
      (Re.seq [ Re.group (Re.rep1 (Re.alt [ Re.alnum; Re.char '_' ])) ])
  in
  try
    let matches = Re.all ~pos:0 identifier_regex text in
    List.fold_left
      (fun acc group ->
        let name = Re.Group.get group 1 in
        let underscore_count =
          String.fold_left
            (fun count c -> if c = '_' then count + 1 else count)
            0 name
        in
        if underscore_count > max_underscores && String.length name > 5 then
          match extract_location_from_parsetree text with
          | Some (line, col) ->
              Issue.Long_identifier_name
                {
                  name;
                  location = { file = filename; line; col };
                  underscore_count;
                  threshold = max_underscores;
                }
              :: acc
          | None -> acc
        else acc)
      [] matches
  with Not_found -> []

let check_parsetree_line filename text =
  let issues = [] in

  (* Check for variant names *)
  let variant_issues = check_variant_in_parsetree filename text in

  (* Check for value names *)
  let value_issues = check_value_in_parsetree filename text in

  (* Check for module names *)
  let module_issues = check_module_in_parsetree filename text in

  (* Check for type names *)
  let type_issues =
    match check_type_in_parsetree filename text with
    | Some v -> [ v ]
    | None -> []
  in

  (* Check for long identifier names *)
  let long_name_issues = check_long_identifier_name filename text in

  let function_naming_issues = check_function_naming filename text in

  issues @ variant_issues @ value_issues @ module_issues
  @ type_issues @ long_name_issues @ function_naming_issues

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
            let issues = check_parsetree_line filename trimmed in
            issues @ acc
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
