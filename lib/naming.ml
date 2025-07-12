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

let convert_module_name name =
  (* Similar to to_snake_case but preserves the capital first letter for modules *)
  if String.length name = 0 then name
  else
    let first_char = String.make 1 name.[0] in
    let rest = String.sub name 1 (String.length name - 1) in
    let rec convert acc = function
      | [] -> String.concat "_" (List.rev acc)
      | c :: rest when c >= 'A' && c <= 'Z' ->
          if acc = [] then
            convert [ String.make 1 (Char.lowercase_ascii c) ] rest
          else convert (String.make 1 (Char.lowercase_ascii c) :: acc) rest
      | c :: rest -> (
          let ch = String.make 1 c in
          match acc with
          | [] -> convert [ ch ] rest
          | h :: t -> convert ((h ^ ch) :: t) rest)
    in
    let converted_rest = convert [] (String.to_seq rest |> List.of_seq) in
    if converted_rest = "" then first_char
    else first_char ^ "_" ^ converted_rest

let check_module_name name =
  let expected = convert_module_name name in
  if name <> expected then Some expected else None

(** Check if an item name has redundant module prefix *)
let has_redundant_prefix item_name_lower module_name =
  String.starts_with ~prefix:(module_name ^ "_") item_name_lower
  || item_name_lower = module_name

(** Create redundant module name issue *)
let create_redundant_name_issue item module_name location item_type =
  Issue.Redundant_module_name
    {
      item_name = item.Outline.name;
      module_name = String.capitalize_ascii module_name;
      location;
      item_type;
    }

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

(* Extract location from outline item *)
let extract_outline_location filename (item : Outline.item) =
  match item.range with
  | Some range ->
      Some
        (Location.create ~file:filename ~start_line:range.start.line
           ~start_col:range.start.col ~end_line:range.start.line
           ~end_col:range.start.col)
  | None -> None

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

let check_redundant_module_name filename outline_opt =
  (* Extract module name from filename *)
  let module_name =
    filename |> Filename.basename |> Filename.chop_extension
    |> String.lowercase_ascii
  in

  Logs.debug (fun m ->
      m "Checking redundant module name for %s (module: %s)" filename
        module_name);

  match outline_opt with
  | None ->
      Logs.debug (fun m -> m "No outline for %s" filename);
      []
  | Some items ->
      List.filter_map
        (fun (item : Outline.item) ->
          let item_name_lower = String.lowercase_ascii item.name in
          let location = extract_outline_location filename item in

          match (item.kind, location) with
          | Outline.Value, Some loc
            when is_function_type (Option.value ~default:"" item.type_sig)
                 && has_redundant_prefix item_name_lower module_name ->
              Some (create_redundant_name_issue item module_name loc "function")
          | Outline.Type, Some loc
            when has_redundant_prefix item_name_lower module_name ->
              Some (create_redundant_name_issue item module_name loc "type")
          | _ -> None)
        items

let check_function_naming filename outline_opt =
  match outline_opt with
  | None -> []
  | Some items ->
      List.filter_map
        (fun (item : Outline.item) ->
          let name = Some item.name in
          let kind =
            match item.kind with Outline.Value -> Some "Value" | _ -> None
          in
          let type_sig = item.type_sig in
          let location = extract_outline_location filename item in
          check_single_function filename name kind type_sig location)
        items

(** Check a list of elements for naming issues *)
let check_elements elements check_fn create_issue_fn =
  List.filter_map
    (fun (elt : Typedtree.elt) ->
      let name_str = Typedtree.name_to_string elt.name in
      match (check_fn name_str, elt.location) with
      | Some result, Some loc -> Some (create_issue_fn name_str loc result)
      | _ -> None)
    elements

(** Built-in variant constructors to skip *)
let builtin_variants = [ "::"; "[]"; "()"; "true"; "false"; "None"; "Some" ]

(** Check for underscore-prefixed bindings that are actually used *)
let check_used_underscore_bindings typedtree =
  let open Typedtree in
  (* First, collect all underscore-prefixed pattern bindings *)
  let underscore_bindings =
    typedtree.patterns
    |> List.filter_map (fun (elt : elt) ->
           let name = name_to_string elt.name in
           if String.length name > 0 && name.[0] = '_' then
             match elt.location with
             | Some loc -> Some (name, loc)
             | None -> None
           else None)
  in

  (* For each underscore binding, check if it's used in identifiers *)
  List.filter_map
    (fun (binding_name, binding_loc) ->
      (* Find all usages of this binding *)
      let usage_locations =
        typedtree.identifiers
        |> List.filter_map (fun (elt : elt) ->
               let ident_name = name_to_string elt.name in
               if ident_name = binding_name then elt.location else None)
      in

      (* If the binding is used, create an issue *)
      if usage_locations <> [] then
        Some
          (Issue.Used_underscore_binding
             { binding_name; location = binding_loc; usage_locations })
      else None)
    underscore_bindings

let check_parsed_structure _filename typedtree =
  (* Check value names *)
  let value_issues =
    check_elements typedtree.Typedtree.patterns check_value_name
      (fun name_str loc expected ->
        Issue.Bad_value_naming
          { value_name = name_str; location = loc; expected })
  in

  (* Check module names *)
  let module_issues =
    check_elements typedtree.Typedtree.modules check_module_name
      (fun name_str loc expected ->
        Issue.Bad_module_naming
          { module_name = name_str; location = loc; expected })
  in

  (* Check type names *)
  let type_issues =
    check_elements typedtree.Typedtree.types
      (fun name_str ->
        if
          name_str <> "t" && name_str <> "id"
          && name_str <> to_snake_case name_str
        then Some "should use snake_case"
        else None)
      (fun name_str loc message ->
        Issue.Bad_type_naming { type_name = name_str; location = loc; message })
  in

  (* Check variant constructors *)
  let variant_issues =
    check_elements typedtree.Typedtree.variants
      (fun name_str ->
        if List.mem name_str builtin_variants then None
        else check_variant_name name_str)
      (fun name_str loc expected ->
        Issue.Bad_variant_naming
          { variant = name_str; location = loc; expected })
  in

  value_issues @ module_issues @ type_issues @ variant_issues

let check ~filename ~outline (typedtree : Typedtree.t) =
  (* Check parsed structure *)
  let structure_issues = check_parsed_structure filename typedtree in

  (* Check long identifier names using the parsed structure *)
  let max_underscores = 3 in
  let all_elts =
    typedtree.Typedtree.identifiers @ typedtree.Typedtree.patterns
    @ typedtree.Typedtree.modules @ typedtree.Typedtree.types
    @ typedtree.Typedtree.exceptions @ typedtree.Typedtree.variants
  in
  let long_name_issues =
    all_elts
    |> List.filter_map (fun (elt : Typedtree.elt) ->
           (* Only check the base name, not the full qualified name *)
           let base_name = elt.name.base in
           let underscore_count =
             String.fold_left
               (fun count c -> if c = '_' then count + 1 else count)
               0 base_name
           in
           if underscore_count > max_underscores && String.length base_name > 5
           then
             match elt.location with
             | Some loc ->
                 (* Use full name for display but count underscores only in base *)
                 let full_name = Typedtree.name_to_string elt.name in
                 Some
                   (Issue.Long_identifier_name
                      {
                        name = full_name;
                        location = loc;
                        underscore_count;
                        threshold = max_underscores;
                      })
             | None -> None
           else None)
  in

  (* Check function naming from outline *)
  let function_naming_issues = check_function_naming filename outline in

  (* Check for redundant module name *)
  let redundant_name_issues = check_redundant_module_name filename outline in

  (* Check for used underscore bindings *)
  let underscore_binding_issues = check_used_underscore_bindings typedtree in

  structure_issues @ long_name_issues @ function_naming_issues
  @ redundant_name_issues @ underscore_binding_issues
