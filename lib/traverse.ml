(** Common traversal helpers for AST analysis *)

(** AST element iteration and filtering *)

let iter_elements ?(filter = fun _ -> true) elements f =
  List.iter (fun elt -> if filter elt then f elt) elements

let filter_map_elements elements f = List.filter_map f elements

let iter_identifiers_with_location (ast_data : Ast.t) f =
  List.iter
    (fun (id : Ast.elt) ->
      match id.location with Some loc -> f id loc | None -> ())
    ast_data.identifiers

(** Location extraction helpers *)

let extract_location (elt : Ast.elt) = elt.location

let extract_outline_location filename (item : Outline.item) =
  match item.range with
  | Some range ->
      Some
        (Location.create ~file:filename ~start_line:range.start.line
           ~start_col:range.start.col ~end_line:range.start.line
           ~end_col:range.start.col)
  | None -> None

(** Name conversion helpers *)

let to_snake_case name =
  (* Convert PascalCase to snake_case *)
  let buffer = Buffer.create (String.length name) in
  let add_char c = Buffer.add_char buffer c in
  let add_underscore () =
    if
      Buffer.length buffer > 0
      && Buffer.nth buffer (Buffer.length buffer - 1) <> '_'
    then Buffer.add_char buffer '_'
  in

  for i = 0 to String.length name - 1 do
    let c = name.[i] in
    if c >= 'A' && c <= 'Z' then (
      if i > 0 then add_underscore ();
      add_char (Char.lowercase_ascii c))
    else add_char c
  done;
  Buffer.contents buffer

let to_pascal_case name =
  (* Convert snake_case to PascalCase *)
  let parts = String.split_on_char '_' name in
  let capitalize_first str =
    if String.length str = 0 then str
    else
      String.mapi (fun i c -> if i = 0 then Char.uppercase_ascii c else c) str
  in
  String.concat "" (List.map capitalize_first parts)

let is_pascal_case name =
  String.length name > 0
  && name.[0] >= 'A'
  && name.[0] <= 'Z'
  && not (String.contains name '_')

let is_snake_case name =
  String.length name > 0
  && name.[0] >= 'a'
  && name.[0] <= 'z'
  && String.for_all
       (fun c -> (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c = '_')
       name

(** AST name matching *)

let match_stdlib_module (name : Ast.name) =
  match (name.prefix, name.base) with
  | [ "Stdlib"; module_name ], base -> Some (module_name, base)
  | _ -> None

let is_module_path expected_prefix expected_base (name : Ast.name) =
  match (name.prefix, name.base) with
  | prefix, base when prefix = expected_prefix && base = expected_base -> true
  | _ -> false

let is_stdlib_module module_name (name : Ast.name) =
  match name.prefix with
  | [ "Stdlib"; m ] when m = module_name -> true
  | _ -> false

(** File processing helpers *)

let process_ocaml_files ctx f =
  let files = Context.all_files ctx in
  List.concat_map
    (fun filename ->
      if
        String.ends_with ~suffix:".ml" filename
        || String.ends_with ~suffix:".mli" filename
      then
        try
          let content =
            In_channel.with_open_text filename In_channel.input_all
          in
          f filename content
        with _ -> []
      else [])
    files

let process_lines content f =
  let lines = String.split_on_char '\n' content in
  List.concat_map
    (fun (line_idx, line) ->
      match f line_idx line with Some result -> [ result ] | None -> [])
    (List.mapi (fun i line -> (i, line)) lines)

let process_lines_with_location filename content f =
  let lines = String.split_on_char '\n' content in
  List.concat_map
    (fun (line_idx, line) ->
      let location =
        Location.create ~file:filename ~start_line:(line_idx + 1) ~start_col:0
          ~end_line:(line_idx + 1) ~end_col:(String.length line)
      in
      match f line_idx line location with
      | Some result -> [ result ]
      | None -> [])
    (List.mapi (fun i line -> (i, line)) lines)

(** Type signature analysis *)

let is_function_type signature =
  String.contains signature '-' && String.contains signature '>'

let extract_return_type signature =
  (* Extract the rightmost part after -> *)
  match String.rindex_opt signature '>' with
  | Some idx when idx > 0 && signature.[idx - 1] = '-' ->
      let return_part =
        String.sub signature (idx + 1) (String.length signature - idx - 1)
      in
      String.trim return_part
  | _ -> signature

let count_parameters signature param_type =
  (* Count occurrences of param_type in function signature *)
  let rec count_matches str pattern acc start =
    match String.index_from_opt str start pattern.[0] with
    | None -> acc
    | Some idx ->
        if
          String.length str >= idx + String.length pattern
          && String.sub str idx (String.length pattern) = pattern
        then count_matches str pattern (acc + 1) (idx + String.length pattern)
        else count_matches str pattern acc (idx + 1)
  in
  count_matches signature param_type 0 0

(** Browse data helpers *)

let iter_value_bindings (browse_data : Browse.t) f =
  List.iter f browse_data.value_bindings

let filter_functions value_bindings =
  List.filter (fun binding -> binding.Browse.is_function) value_bindings

let iter_function_bindings browse_data f =
  let functions = filter_functions browse_data.Browse.value_bindings in
  List.iter f functions

(** Common validation patterns *)

let check_identifier_pattern identifiers pattern_match issue_constructor =
  List.filter_map
    (fun (id : Ast.elt) ->
      match id.location with
      | Some loc ->
          let name = id.name in
          if pattern_match name then Some (issue_constructor ~loc) else None
      | None -> None)
    identifiers

let check_module_usage identifiers module_name issue_constructor =
  check_identifier_pattern identifiers
    (fun name ->
      match name.prefix with
      | [ "Stdlib"; m ] when m = module_name -> true
      | [ m ] when m = module_name -> true
      | _ -> false)
    issue_constructor

let check_function_usage identifiers module_name function_name issue_constructor
    =
  check_identifier_pattern identifiers
    (fun name ->
      match (name.prefix, name.base) with
      | [ "Stdlib"; m ], base when m = module_name && base = function_name ->
          true
      | [ m ], base when m = module_name && base = function_name -> true
      | _ -> false)
    issue_constructor

(** Common pattern for checking elements with name validation *)

let check_elements elements check_fn create_issue_fn =
  List.filter_map
    (fun (elt : Ast.elt) ->
      let name_str = Ast.name_to_string elt.name in
      match (check_fn name_str, elt.location) with
      | Some result, Some loc -> Some (create_issue_fn name_str loc result)
      | _ -> None)
    elements

(** Helper for extracting specific AST element types *)

let extract_by_kind (ast_data : Ast.t) kind =
  (* Different AST element types are stored in different fields *)
  match kind with
  | "identifier" -> ast_data.identifiers
  | "pattern" -> ast_data.patterns
  | "module" -> ast_data.modules
  | "type" -> ast_data.types
  | "exception" -> ast_data.exceptions
  | "variant" -> ast_data.variants
  | _ -> []

let extract_values (ast_data : Ast.t) = ast_data.identifiers
let extract_types (ast_data : Ast.t) = ast_data.types
let extract_modules (ast_data : Ast.t) = ast_data.modules
let extract_constructors (ast_data : Ast.t) = ast_data.variants
