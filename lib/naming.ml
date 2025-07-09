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

(* Helper to extract string field from JSON *)
let find_string_field name fields =
  match List.assoc_opt name fields with Some (`String s) -> Some s | _ -> None

(* Helper to check if a type signature is a function type *)
let is_function_type type_sig = String.contains type_sig '-'

(* Helper to extract return type from function signature *)
let get_return_type type_sig =
  (* Find the last -> in the type signature *)
  try
    let last_arrow = String.rindex type_sig '>' in
    if last_arrow > 0 && type_sig.[last_arrow - 1] = '-' then
      let return_start = last_arrow + 1 in
      String.trim
        (String.sub type_sig return_start
           (String.length type_sig - return_start))
    else type_sig
  with Not_found -> type_sig

(* Check if return type is an option *)
let returns_option return_type =
  String.ends_with ~suffix:" option" return_type
  || return_type = "option"
  || Re.execp (Re.compile (Re.str "option")) return_type

(* Extract location from outline fields *)
let extract_outline_location filename fields =
  match List.assoc_opt "start" fields with
  | Some (`Assoc pos_fields) ->
      let line =
        match List.assoc_opt "line" pos_fields with
        | Some (`Int l) -> l
        | _ -> 1
      in
      let col =
        match List.assoc_opt "col" pos_fields with Some (`Int c) -> c | _ -> 0
      in
      Some { Issue.file = filename; line; col }
  | _ -> None

(* Check a single function for naming issues *)
let check_single_function _filename name kind type_sig location =
  match (name, kind, type_sig, location) with
  | Some n, Some "Value", Some ts, Some loc when is_function_type ts ->
      let return_type = get_return_type ts in
      let is_option = returns_option return_type in

      (* Check get_* functions or just 'get' *)
      if (String.starts_with ~prefix:"get_" n || n = "get") && is_option then
        Some
          (Issue.Bad_function_naming
             {
               function_name = n;
               location = loc;
               suggestion =
                 (if n = "get" then "find"
                  else
                    let suffix = String.sub n 4 (String.length n - 4) in
                    "find_" ^ suffix);
             }) (* Check find_* functions or just 'find' *)
      else if
        (String.starts_with ~prefix:"find_" n || n = "find") && not is_option
      then
        Some
          (Issue.Bad_function_naming
             {
               function_name = n;
               location = loc;
               suggestion =
                 (if n = "find" then "get"
                  else
                    let suffix = String.sub n 5 (String.length n - 5) in
                    "get_" ^ suffix);
             })
      else None
  | _ -> None

let check_function_naming filename outline_opt =
  match outline_opt with
  | None -> []
  | Some (`List items) ->
      List.filter_map
        (fun item ->
          match item with
          | `Assoc fields ->
              let name = find_string_field "name" fields in
              let kind = find_string_field "kind" fields in
              let type_sig = find_string_field "type" fields in
              let location = extract_outline_location filename fields in
              check_single_function filename name kind type_sig location
          | _ -> None)
        items
  | Some _ -> []

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

  issues @ variant_issues @ value_issues @ module_issues @ type_issues
  @ long_name_issues

let check ~filename ~outline data =
  match data with
  | `String text ->
      (* Split text by lines and check each line *)
      let lines = String.split_on_char '\n' text in
      let line_issues =
        List.fold_left
          (fun acc line ->
            let trimmed = String.trim line in
            if trimmed <> "" then
              let issues = check_parsetree_line filename trimmed in
              issues @ acc
            else acc)
          [] lines
      in
      (* Check function naming once for the whole file *)
      let function_naming_issues = check_function_naming filename outline in
      line_issues @ function_naming_issues
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
