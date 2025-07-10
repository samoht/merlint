type issue_type =
  | Complexity
  | Function_length
  | Deep_nesting
  | Obj_magic
  | Catch_all_exception
  | Str_module
  | Printf_module
  | Variant_naming
  | Module_naming
  | Value_naming
  | Type_naming
  | Long_identifier
  | Function_naming
  | Missing_mli_doc
  | Missing_value_doc
  | Bad_doc_style
  | Missing_standard_function
  | Missing_ocamlformat_file
  | Missing_mli_file

type t =
  | Complexity_exceeded of {
      name : string;
      location : Location.t;
      complexity : int;
      threshold : int;
    }
  | Function_too_long of {
      name : string;
      location : Location.t;
      length : int;
      threshold : int;
    }
  | No_obj_magic of { location : Location.t }
  | Missing_mli_doc of { module_name : string; file : string }
  | Missing_value_doc of { value_name : string; location : Location.t }
  | Bad_doc_style of {
      value_name : string;
      location : Location.t;
      message : string;
    }
  | Bad_variant_naming of {
      variant : string;
      location : Location.t;
      expected : string;
    }
  | Bad_module_naming of {
      module_name : string;
      location : Location.t;
      expected : string;
    }
  | Bad_value_naming of {
      value_name : string;
      location : Location.t;
      expected : string;
    }
  | Bad_type_naming of {
      type_name : string;
      location : Location.t;
      message : string;
    }
  | Catch_all_exception of { location : Location.t }
  | Use_str_module of { location : Location.t }
  | Use_printf_module of { location : Location.t; module_used : string }
  | Deep_nesting of {
      name : string;
      location : Location.t;
      depth : int;
      threshold : int;
    }
  | Missing_standard_function of {
      module_name : string;
      type_name : string;
      missing : string list;
      file : string;
    }
  | Missing_ocamlformat_file of { location : Location.t }
  | Missing_mli_file of {
      ml_file : string;
      expected_mli : string;
      location : Location.t;
    }
  | Long_identifier_name of {
      name : string;
      location : Location.t;
      underscore_count : int;
      threshold : int;
    }
  | Bad_function_naming of {
      function_name : string;
      location : Location.t;
      suggestion : string;
    }

let pp ppf = function
  | Complexity_exceeded { name; location; complexity; threshold } ->
      Fmt.pf ppf
        "%a: Function '%s' has cyclomatic complexity of %d (threshold: %d)"
        Location.pp location name complexity threshold
  | Function_too_long { name; location; length; threshold } ->
      Fmt.pf ppf "%a: Function '%s' is %d lines long (threshold: %d)"
        Location.pp location name length threshold
  | Deep_nesting { name; location; depth; threshold } ->
      Fmt.pf ppf "%a: Function '%s' has nesting depth of %d (threshold: %d)"
        Location.pp location name depth threshold
  | No_obj_magic { location } ->
      Fmt.pf ppf "%a: Never use Obj.magic" Location.pp location
  | Catch_all_exception { location } ->
      Fmt.pf ppf "%a: Avoid catch-all exception handler" Location.pp location
  | Use_str_module { location } ->
      Fmt.pf ppf "%a: Use Re module instead of Str" Location.pp location
  | Use_printf_module { location; module_used } ->
      Fmt.pf ppf "%a: Use Fmt module instead of %s" Location.pp location
        module_used
  | Bad_variant_naming { variant; location; expected } ->
      Fmt.pf ppf "%a: Variant '%s' should be '%s'" Location.pp location variant
        expected
  | Bad_module_naming { module_name; location; expected } ->
      Fmt.pf ppf "%a: Module '%s' should be '%s'" Location.pp location
        module_name expected
  | Bad_value_naming { value_name; location; expected } ->
      Fmt.pf ppf "%a: Value '%s' should be '%s'" Location.pp location value_name
        expected
  | Bad_type_naming { type_name; location; message } ->
      Fmt.pf ppf "%a: Type '%s' %s" Location.pp location type_name message
  | Bad_function_naming { function_name; location; suggestion } ->
      Fmt.pf ppf
        "%a: Function '%s' should use '%s' (get_* for extraction, find_* for \
         search)"
        Location.pp location function_name suggestion
  | Missing_mli_doc { module_name; file } ->
      Fmt.pf ppf "%s:1:0: Module '%s' missing documentation comment" file
        module_name
  | Missing_value_doc { value_name; location } ->
      Fmt.pf ppf "%a: Value '%s' missing documentation" Location.pp location
        value_name
  | Bad_doc_style { value_name; location; message } ->
      Fmt.pf ppf "%a: Value '%s' documentation issue: %s" Location.pp location
        value_name message
  | Missing_standard_function { module_name; type_name; missing; file } ->
      Fmt.pf ppf "%s: Module '%s' with type '%s' missing standard functions: %a"
        file module_name type_name
        Fmt.(list ~sep:(any ", ") string)
        missing
  | Missing_ocamlformat_file _ ->
      Fmt.pf ppf
        "(project): Missing .ocamlformat file for consistent formatting"
  | Missing_mli_file { location; _ } ->
      Fmt.pf ppf "%a: missing interface file" Location.pp location
  | Long_identifier_name { name; location; underscore_count; _ } ->
      Fmt.pf ppf "%a: '%s' has too many underscores (%d)" Location.pp location
        name underscore_count

let format v = Fmt.str "%a" pp v

let rec take n lst =
  if n <= 0 then []
  else match lst with [] -> [] | h :: t -> h :: take (n - 1) t

let get_type = function
  | Complexity_exceeded _ -> Complexity
  | Function_too_long _ -> Function_length
  | Deep_nesting _ -> Deep_nesting
  | No_obj_magic _ -> Obj_magic
  | Catch_all_exception _ -> Catch_all_exception
  | Use_str_module _ -> Str_module
  | Use_printf_module _ -> Printf_module
  | Bad_variant_naming _ -> Variant_naming
  | Bad_module_naming _ -> Module_naming
  | Bad_value_naming _ -> Value_naming
  | Bad_type_naming _ -> Type_naming
  | Long_identifier_name _ -> Long_identifier
  | Bad_function_naming _ -> Function_naming
  | Missing_mli_doc _ -> Missing_mli_doc
  | Missing_value_doc _ -> Missing_value_doc
  | Bad_doc_style _ -> Bad_doc_style
  | Missing_standard_function _ -> Missing_standard_function
  | Missing_ocamlformat_file _ -> Missing_ocamlformat_file
  | Missing_mli_file _ -> Missing_mli_file

let hint_for_renames issue_type get_old_new issues =
  let renames = List.filter_map get_old_new issues in
  match renames with
  | [] -> None
  | _ ->
      let prefix =
        match issue_type with
        | Variant_naming -> "Rename these variant constructors:"
        | Module_naming -> "Rename these modules:"
        | Value_naming -> "Rename these values:"
        | Function_naming ->
            "Rename these functions based on their return types:"
        | _ -> "Rename:"
      in
      Some
        (Fmt.str "%s\n     %s" prefix
           (String.concat "\n     "
              (List.map
                 (fun (old, new_, loc) ->
                   let prefix =
                     match issue_type with
                     | Module_naming -> "module "
                     | Value_naming | Function_naming -> "let "
                     | _ -> ""
                   in
                   Fmt.str "%a: %s%s → %s%s" Location.pp loc prefix old prefix
                     new_)
                 renames)))

let hint_long_identifiers issues =
  let names =
    List.filter_map
      (function
        | Long_identifier_name { name; location; _ } -> Some (name, location)
        | _ -> None)
      issues
  in
  Some
    (Fmt.str "Shorten these identifiers by using more concise names:\n     %s"
       (String.concat "\n     "
          (List.map
             (fun (name, loc) -> Fmt.str "%a: %s" Location.pp loc name)
             names)))

let hint_missing_mli_doc issues =
  let modules =
    List.filter_map
      (function
        | Missing_mli_doc { module_name; file } -> Some (module_name, file)
        | _ -> None)
      issues
  in
  Some
    (Fmt.str
       "Add module documentation at the top of these .mli files:\n\
       \     %s\n\n\
       \     Template:\n\
       \     (** %s\n\n\
       \         This module provides types and functions for %s. *)"
       (String.concat "\n     "
          (List.map
             (fun (module_name, file) ->
               Fmt.str "%s:1: Add documentation for module %s" file module_name)
             modules))
       "Brief one-line summary" "detailed description of what this module does")

let hint_missing_value_doc issues =
  let values =
    List.filter_map
      (function
        | Missing_value_doc { value_name; location } ->
            Some (value_name, location)
        | _ -> None)
      issues
    |> take 5
  in
  Some
    (Fmt.str
       "Add documentation for these public values:\n\
       \     %s\n\n\
       \     Template for functions:\n\
       \     (** [%s arg1 arg2] %s ... *)\n\n\
       \     Template for values:\n\
       \     (** %s *)"
       (String.concat "\n     "
          (List.map
             (fun (name, loc) ->
               Fmt.str "%a: Document '%s'" Location.pp loc name)
             values))
       "function_name" "does/returns/computes"
       "Description of what this value represents")

let hint_missing_standard_function issues =
  let missing_by_module =
    List.filter_map
      (function
        | Missing_standard_function { module_name; type_name; missing; file } ->
            Some (module_name, type_name, missing, file)
        | _ -> None)
      issues
  in
  Some
    (Fmt.str
       "Implement these standard functions:\n\
       \     %s\n\n\
       \     Common implementations:\n\
       \     - equal: let equal = (=)\n\
       \     - compare: let compare = compare\n\
       \     - pp: let pp ppf t = Fmt.pf ppf \"<custom format>\"\n\
       \     - to_string: let to_string t = Format.asprintf \"%%a\" pp t"
       (String.concat "\n     "
          (List.map
             (fun (mod_name, type_name, missing, file) ->
               Fmt.str "%s: Add %s for type %s in module %s" file
                 (String.concat ", " missing)
                 type_name mod_name)
             missing_by_module)))

let hint_missing_mli_file issues =
  let files =
    List.filter_map
      (function
        | Missing_mli_file { ml_file; expected_mli; _ } ->
            Some (ml_file, expected_mli)
        | _ -> None)
      issues
    |> List.sort_uniq compare
  in
  Some
    (Fmt.str "Create these interface files:\n     %s"
       (String.concat "\n     "
          (List.map
             (fun (ml, mli) ->
               Fmt.str "Create %s (copy public signatures from %s)" mli ml)
             files)))

let hint_complexity_exceeded issues =
  let functions =
    List.filter_map
      (function
        | Complexity_exceeded { name; location; complexity; _ } ->
            Some (name, location, complexity)
        | _ -> None)
      issues
  in
  Some
    (Fmt.str
       "Extract complex conditional logic from these functions into smaller \
        helper functions:\n\
       \     %s"
       (String.concat "\n     "
          (List.map
             (fun (name, loc, _) ->
               Fmt.str "%a: function %s" Location.pp loc name)
             functions)))

let hint_function_too_long issues =
  let functions =
    List.filter_map
      (function
        | Function_too_long { name; location; _ } -> Some (name, location)
        | _ -> None)
      issues
  in
  Some
    (Fmt.str
       "Split these long functions by extracting logical sections into \
        separate functions:\n\
       \     %s"
       (String.concat "\n     "
          (List.map
             (fun (name, loc) -> Fmt.str "%a: function %s" Location.pp loc name)
             functions)))

let hint_simple_cases (issue_type : issue_type) =
  match issue_type with
  | Deep_nesting ->
      Some
        "Replace deeply nested if-then-else chains with pattern matching or \
         early returns using 'when' guards."
  | Obj_magic ->
      Some
        "Replace all Obj.magic calls with proper type definitions. Define a \
         variant type or use GADTs to represent the different cases safely."
  | Catch_all_exception ->
      Some
        "Replace catch-all exception handlers with specific exception \
         patterns. Add explicit handlers for expected exceptions."
  | Str_module ->
      Some
        "Replace all Str module usage:\n\
        \     1. Add 're' to your dune dependencies: (libraries ... re)\n\
        \     2. Replace Str.regexp with Re.compile (Re.str ...)\n\
        \     3. Replace Str.string_match with Re.execp"
  | Printf_module ->
      Some
        "Replace Printf/Format module usage with Fmt:\n\
        \     1. Add 'fmt' to your dune dependencies: (libraries ... fmt)\n\
        \     2. Replace Printf.printf with Fmt.pr\n\
        \     3. Replace Printf.sprintf with Fmt.str\n\
        \     4. Replace Format.printf with Fmt.pr\n\
        \     5. Replace Format.asprintf with Fmt.str\n\
        \     Example: Fmt.pr \"Hello %s!@.\" name"
  | Type_naming ->
      Some
        "Rename all type definitions to use snake_case (e.g., myType → \
         my_type)."
  | Bad_doc_style ->
      Some "Fix documentation formatting to follow OCaml conventions."
  | _ -> None

let find_grouped_hint issue_type issues =
  match issue_type with
  | Complexity -> hint_complexity_exceeded issues
  | Function_length -> hint_function_too_long issues
  | Deep_nesting | Obj_magic | Catch_all_exception | Str_module | Printf_module
  | Type_naming | Bad_doc_style ->
      hint_simple_cases issue_type
  | Variant_naming ->
      hint_for_renames issue_type
        (function
          | Bad_variant_naming { variant; expected; location; _ } ->
              Some (variant, expected, location)
          | _ -> None)
        issues
  | Module_naming ->
      hint_for_renames issue_type
        (function
          | Bad_module_naming { module_name; expected; location } ->
              Some (module_name, expected, location)
          | _ -> None)
        issues
  | Value_naming ->
      hint_for_renames issue_type
        (function
          | Bad_value_naming { value_name; expected; location } ->
              Some (value_name, expected, location)
          | _ -> None)
        issues
  | Long_identifier -> hint_long_identifiers issues
  | Function_naming ->
      hint_for_renames issue_type
        (function
          | Bad_function_naming { function_name; suggestion; location } ->
              Some (function_name, suggestion, location)
          | _ -> None)
        issues
  | Missing_mli_doc -> hint_missing_mli_doc issues
  | Missing_value_doc -> hint_missing_value_doc issues
  | Missing_standard_function -> hint_missing_standard_function issues
  | Missing_ocamlformat_file ->
      Some
        "Create file '.ocamlformat' in project root with:\n\
        \     profile = default\n\
        \     version = 0.26.1"
  | Missing_mli_file -> hint_missing_mli_file issues

(* Assign priority to issues - lower number = higher priority *)
let priority = function
  | No_obj_magic _ | Catch_all_exception _ -> 1
  | Complexity_exceeded _ | Deep_nesting _ | Function_too_long _ -> 2
  | Use_str_module _ | Use_printf_module _ | Bad_variant_naming _
  | Missing_mli_file _ | Bad_module_naming _ | Bad_value_naming _
  | Bad_type_naming _ | Long_identifier_name _ | Bad_function_naming _ ->
      3
  | Missing_mli_doc _ | Missing_value_doc _ | Bad_doc_style _
  | Missing_standard_function _ | Missing_ocamlformat_file _ ->
      4

let find_location = function
  | Complexity_exceeded { location; _ }
  | Function_too_long { location; _ }
  | No_obj_magic { location }
  | Missing_value_doc { location; _ }
  | Bad_doc_style { location; _ }
  | Bad_variant_naming { location; _ }
  | Bad_module_naming { location; _ }
  | Bad_value_naming { location; _ }
  | Bad_type_naming { location; _ }
  | Catch_all_exception { location }
  | Use_str_module { location }
  | Use_printf_module { location; _ }
  | Deep_nesting { location; _ }
  | Missing_ocamlformat_file { location }
  | Missing_mli_file { location; _ }
  | Long_identifier_name { location; _ }
  | Bad_function_naming { location; _ } ->
      Some location
  | _ -> None

let find_file = function
  | Missing_mli_doc { file; _ } | Missing_standard_function { file; _ } ->
      Some file
  | _ -> None

(* Compare issues for sorting *)
let compare a b =
  let pa = priority a in
  let pb = priority b in
  if pa <> pb then compare pa pb
  else
    match (find_file a, find_file b) with
    | Some f1, Some f2 -> String.compare f1 f2
    | _ -> (
        match (find_location a, find_location b) with
        | Some l1, Some l2 -> Location.compare l1 l2
        | _ -> 0)
