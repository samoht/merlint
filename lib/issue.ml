type location = { file : string; line : int; col : int }

type t =
  | Complexity_exceeded of {
      name : string;
      location : location;
      complexity : int;
      threshold : int;
    }
  | Function_too_long of {
      name : string;
      location : location;
      length : int;
      threshold : int;
    }
  | No_obj_magic of { location : location }
  | Missing_mli_doc of { module_name : string; file : string }
  | Missing_value_doc of { value_name : string; location : location }
  | Bad_doc_style of {
      value_name : string;
      location : location;
      message : string;
    }
  | Bad_variant_naming of {
      variant : string;
      location : location;
      expected : string;
    }
  | Bad_module_naming of {
      module_name : string;
      location : location;
      expected : string;
    }
  | Bad_value_naming of {
      value_name : string;
      location : location;
      expected : string;
    }
  | Bad_type_naming of {
      type_name : string;
      location : location;
      message : string;
    }
  | Catch_all_exception of { location : location }
  | Use_str_module of { location : location }
  | Use_printf_module of { location : location; module_used : string }
  | Deep_nesting of {
      name : string;
      location : location;
      depth : int;
      threshold : int;
    }
  | Missing_standard_function of {
      module_name : string;
      type_name : string;
      missing : string list;
      file : string;
    }
  | Missing_ocamlformat_file of { location : location }
  | Missing_mli_file of {
      ml_file : string;
      expected_mli : string;
      location : location;
    }
  | Long_identifier_name of {
      name : string;
      location : location;
      underscore_count : int;
      threshold : int;
    }
  | Bad_function_naming of {
      function_name : string;
      location : location;
      suggestion : string;
    }

let pp_location ppf loc = Fmt.pf ppf "%s:%d:%d" loc.file loc.line loc.col


let pp ppf = function
  | Complexity_exceeded { name; location; complexity; threshold } ->
      Fmt.pf ppf "%a: Function '%s' has cyclomatic complexity of %d (threshold: %d)"
        pp_location location name complexity threshold
  | Function_too_long { name; location; length; threshold } ->
      Fmt.pf ppf "%a: Function '%s' is %d lines long (threshold: %d)"
        pp_location location name length threshold
  | Deep_nesting { name; location; depth; threshold } ->
      Fmt.pf ppf "%a: Function '%s' has nesting depth of %d (threshold: %d)"
        pp_location location name depth threshold
  | No_obj_magic { location } ->
      Fmt.pf ppf "%a: Never use Obj.magic" pp_location location
  | Catch_all_exception { location } ->
      Fmt.pf ppf "%a: Avoid catch-all exception handler" pp_location location
  | Use_str_module { location } ->
      Fmt.pf ppf "%a: Use Re module instead of Str" pp_location location
  | Use_printf_module { location; module_used } ->
      Fmt.pf ppf "%a: Use Fmt module instead of %s" pp_location location module_used
  | Bad_variant_naming { variant; location; expected } ->
      Fmt.pf ppf "%a: Variant '%s' should be '%s'" pp_location location variant expected
  | Bad_module_naming { module_name; location; expected } ->
      Fmt.pf ppf "%a: Module '%s' should be '%s'" pp_location location module_name expected
  | Bad_value_naming { value_name; location; expected } ->
      Fmt.pf ppf "%a: Value '%s' should be '%s'" pp_location location value_name expected
  | Bad_type_naming { type_name; location; message } ->
      Fmt.pf ppf "%a: Type '%s' %s" pp_location location type_name message
  | Bad_function_naming { function_name; location; suggestion } ->
      Fmt.pf ppf "%a: Function '%s' should use '%s' (get_* for extraction, find_* for search)"
        pp_location location function_name suggestion
  | Missing_mli_doc { module_name; file } ->
      Fmt.pf ppf "%s:1:0: Module '%s' missing documentation comment" file module_name
  | Missing_value_doc { value_name; location } ->
      Fmt.pf ppf "%a: Value '%s' missing documentation" pp_location location value_name
  | Bad_doc_style { value_name; location; message } ->
      Fmt.pf ppf "%a: Value '%s' documentation issue: %s" pp_location location value_name message
  | Missing_standard_function { module_name; type_name; missing; file } ->
      Fmt.pf ppf "%s: Module '%s' with type '%s' missing standard functions: %a"
        file module_name type_name Fmt.(list ~sep:(any ", ") string) missing
  | Missing_ocamlformat_file _ ->
      Fmt.pf ppf "(project): Missing .ocamlformat file for consistent formatting"
  | Missing_mli_file { location; _ } ->
      Fmt.pf ppf "%a: missing interface file" pp_location location
  | Long_identifier_name { name; location; underscore_count; _ } ->
      Fmt.pf ppf "%a: '%s' has too many underscores (%d)"
        pp_location location name underscore_count

let format v = Fmt.str "%a" pp v

let rec take n lst =
  if n <= 0 then []
  else match lst with [] -> [] | h :: t -> h :: take (n - 1) t

let get_issue_type = function
  | Complexity_exceeded _ -> "complexity_exceeded"
  | Function_too_long _ -> "function_too_long"
  | Deep_nesting _ -> "deep_nesting"
  | No_obj_magic _ -> "no_obj_magic"
  | Catch_all_exception _ -> "catch_all_exception"
  | Use_str_module _ -> "use_str_module"
  | Use_printf_module _ -> "use_printf_module"
  | Bad_variant_naming _ -> "bad_variant_naming"
  | Bad_module_naming _ -> "bad_module_naming"
  | Bad_value_naming _ -> "bad_value_naming"
  | Bad_type_naming _ -> "bad_type_naming"
  | Long_identifier_name _ -> "long_identifier_name"
  | Bad_function_naming _ -> "bad_function_naming"
  | Missing_mli_doc _ -> "missing_mli_doc"
  | Missing_value_doc _ -> "missing_value_doc"
  | Bad_doc_style _ -> "bad_doc_style"
  | Missing_standard_function _ -> "missing_standard_function"
  | Missing_ocamlformat_file _ -> "missing_ocamlformat_file"
  | Missing_mli_file _ -> "missing_mli_file"

let hint_for_renames issue_type get_old_new issues =
  let renames = List.filter_map get_old_new issues in
  match renames with
  | [] -> None
  | _ ->
      let prefix =
        match issue_type with
        | "bad_variant_naming" -> "Rename these variant constructors:"
        | "bad_module_naming" -> "Rename these modules:"
        | "bad_value_naming" -> "Rename these values:"
        | "bad_function_naming" ->
            "Rename these functions based on their return types:"
        | _ -> "Rename:"
      in
      Some
        (Printf.sprintf "%s\n     %s" prefix
           (String.concat "\n     "
              (List.map
                 (fun (old, new_, loc) ->
                   let prefix =
                     match issue_type with
                     | "bad_module_naming" -> "module "
                     | "bad_value_naming" | "bad_function_naming" -> "let "
                     | _ -> ""
                   in
                   Printf.sprintf "%s:%d: %s%s → %s%s" loc.file loc.line prefix
                     old prefix new_)
                 renames)))

let find_grouped_hint issue_type issues =
  match issue_type with
  | "complexity_exceeded" ->
      let functions =
        List.filter_map
          (function
            | Complexity_exceeded { name; location; complexity; _ } ->
                Some (name, location, complexity)
            | _ -> None)
          issues
      in
      Some
        (Printf.sprintf
           "Extract complex conditional logic from these functions into \
            smaller helper functions:\n\
           \     %s"
           (String.concat "\n     "
              (List.map
                 (fun (name, loc, _) ->
                   Printf.sprintf "%s:%d: function %s" loc.file loc.line name)
                 functions)))
  | "function_too_long" ->
      let functions =
        List.filter_map
          (function
            | Function_too_long { name; location; _ } -> Some (name, location)
            | _ -> None)
          issues
      in
      Some
        (Printf.sprintf
           "Split these long functions by extracting logical sections into \
            separate functions:\n\
           \     %s"
           (String.concat "\n     "
              (List.map
                 (fun (name, loc) ->
                   Printf.sprintf "%s:%d: function %s" loc.file loc.line name)
                 functions)))
  | "deep_nesting" ->
      Some
        "Replace deeply nested if-then-else chains with pattern matching or \
         early returns using 'when' guards."
  | "no_obj_magic" ->
      Some
        "Replace all Obj.magic calls with proper type definitions. Define a \
         variant type or use GADTs to represent the different cases safely."
  | "catch_all_exception" ->
      Some
        "Replace catch-all exception handlers with specific exception \
         patterns. Add explicit handlers for expected exceptions."
  | "use_str_module" ->
      Some
        "Replace all Str module usage:\n\
        \     1. Add 're' to your dune dependencies: (libraries ... re)\n\
        \     2. Replace Str.regexp with Re.compile (Re.str ...)\n\
        \     3. Replace Str.string_match with Re.execp"
  | "use_printf_module" ->
      Some
        "Replace Printf/Format module usage with Fmt:\n\
        \     1. Add 'fmt' to your dune dependencies: (libraries ... fmt)\n\
        \     2. Replace Printf.printf with Fmt.pr\n\
        \     3. Replace Printf.sprintf with Fmt.str\n\
        \     4. Replace Format.printf with Fmt.pr\n\
        \     5. Replace Format.asprintf with Fmt.str\n\
        \     Example: Fmt.pr \"Hello %s!@.\" name"
  | "bad_variant_naming" ->
      hint_for_renames issue_type
        (function
          | Bad_variant_naming { variant; expected; location; _ } ->
              Some (variant, expected, location)
          | _ -> None)
        issues
  | "bad_module_naming" ->
      hint_for_renames issue_type
        (function
          | Bad_module_naming { module_name; expected; location } ->
              Some (module_name, expected, location)
          | _ -> None)
        issues
  | "bad_value_naming" ->
      hint_for_renames issue_type
        (function
          | Bad_value_naming { value_name; expected; location } ->
              Some (value_name, expected, location)
          | _ -> None)
        issues
  | "bad_type_naming" ->
      Some
        "Rename all type definitions to use snake_case (e.g., myType → \
         my_type)."
  | "long_identifier_name" ->
      let names =
        List.filter_map
          (function
            | Long_identifier_name { name; location; _ } -> Some (name, location)
            | _ -> None)
          issues
      in
      Some
        (Printf.sprintf
           "Shorten these identifiers by using more concise names:\n     %s"
           (String.concat "\n     "
              (List.map
                 (fun (name, loc) ->
                   Printf.sprintf "%s:%d: %s" loc.file loc.line name)
                 names)))
  | "bad_function_naming" ->
      hint_for_renames issue_type
        (function
          | Bad_function_naming { function_name; suggestion; location } ->
              Some (function_name, suggestion, location)
          | _ -> None)
        issues
  | "missing_mli_doc" ->
      let modules =
        List.filter_map
          (function
            | Missing_mli_doc { module_name; file } -> Some (module_name, file)
            | _ -> None)
          issues
      in
      Some
        (Printf.sprintf
           "Add module documentation at the top of these .mli files:\n\
           \     %s\n\n\
           \     Template:\n\
           \     (** %s\n\n\
           \         This module provides types and functions for %s. *)"
           (String.concat "\n     "
              (List.map
                 (fun (module_name, file) ->
                   Printf.sprintf "%s:1: Add documentation for module %s" file
                     module_name)
                 modules))
           "Brief one-line summary"
           "detailed description of what this module does")
  | "missing_value_doc" ->
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
        (Printf.sprintf
           "Add documentation for these public values:\n\
           \     %s\n\n\
           \     Template for functions:\n\
           \     (** [%s arg1 arg2] %s ... *)\n\n\
           \     Template for values:\n\
           \     (** %s *)"
           (String.concat "\n     "
              (List.map
                 (fun (name, loc) ->
                   Printf.sprintf "%s:%d: Document '%s'" loc.file loc.line name)
                 values))
           "function_name" "does/returns/computes"
           "Description of what this value represents")
  | "bad_doc_style" ->
      Some "Fix documentation formatting to follow OCaml conventions."
  | "missing_standard_function" ->
      let missing_by_module =
        List.filter_map
          (function
            | Missing_standard_function
                { module_name; type_name; missing; file } ->
                Some (module_name, type_name, missing, file)
            | _ -> None)
          issues
      in
      Some
        (Printf.sprintf
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
                   Printf.sprintf "%s: Add %s for type %s in module %s" file
                     (String.concat ", " missing)
                     type_name mod_name)
                 missing_by_module)))
  | "missing_ocamlformat_file" ->
      Some
        "Create file '.ocamlformat' in project root with:\n\
        \     profile = default\n\
        \     version = 0.26.1"
  | "missing_mli_file" ->
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
        (Printf.sprintf "Create these interface files:\n     %s"
           (String.concat "\n     "
              (List.map
                 (fun (ml, mli) ->
                   Printf.sprintf "Create %s (copy public signatures from %s)"
                     mli ml)
                 files)))
  | _ -> None

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

let compare_locations l1 l2 =
  let fc = String.compare l1.file l2.file in
  if fc <> 0 then fc else compare l1.line l2.line

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
        | Some l1, Some l2 -> compare_locations l1 l2
        | _ -> 0)
