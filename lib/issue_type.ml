type t =
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
  | Redundant_module_name
  | Used_underscore_binding
  | Error_pattern
  | Boolean_blindness
  | Mutable_state
  | Missing_mli_doc
  | Missing_value_doc
  | Bad_doc_style
  | Missing_standard_function
  | Missing_ocamlformat_file
  | Missing_mli_file
  | Test_exports_module
  | Silenced_warning
  | Missing_test_file
  | Test_without_library
  | Test_suite_not_included
  (* Logging Rules *)
  | Missing_log_source

let error_code = function
  | Complexity -> "E001"
  | Function_length -> "E005"
  | Deep_nesting -> "E010"
  | Obj_magic -> "E100"
  | Catch_all_exception -> "E105"
  | Silenced_warning -> "E110"
  | Str_module -> "E200"
  | Printf_module -> "E205"
  | Variant_naming -> "E300"
  | Module_naming -> "E305"
  | Value_naming -> "E310"
  | Type_naming -> "E315"
  | Long_identifier -> "E320"
  | Function_naming -> "E325"
  | Redundant_module_name -> "E330"
  | Used_underscore_binding -> "E335"
  | Error_pattern -> "E340"
  | Boolean_blindness -> "E350"
  | Mutable_state -> "E351"
  | Missing_mli_doc -> "E400"
  | Missing_value_doc -> "E405"
  | Bad_doc_style -> "E410"
  | Missing_standard_function -> "E415"
  | Missing_ocamlformat_file -> "E500"
  | Missing_mli_file -> "E505"
  | Test_exports_module -> "E600"
  | Missing_test_file -> "E605"
  | Test_without_library -> "E610"
  | Test_suite_not_included -> "E615"
  | Missing_log_source -> "E510"

(* Build a reverse mapping from error codes to issue types *)
let error_code_to_type =
  let map = Hashtbl.create 50 in
  let add_mapping issue_type =
    let code = error_code issue_type in
    Hashtbl.add map code issue_type
  in
  (* Add all issue types - this ensures we don't miss any *)
  List.iter add_mapping
    [
      Complexity;
      Function_length;
      Deep_nesting;
      Obj_magic;
      Catch_all_exception;
      Silenced_warning;
      Str_module;
      Printf_module;
      Variant_naming;
      Module_naming;
      Value_naming;
      Type_naming;
      Long_identifier;
      Function_naming;
      Redundant_module_name;
      Used_underscore_binding;
      Error_pattern;
      Boolean_blindness;
      Mutable_state;
      Missing_mli_doc;
      Missing_value_doc;
      Bad_doc_style;
      Missing_standard_function;
      Missing_ocamlformat_file;
      Missing_mli_file;
      Test_exports_module;
      Missing_test_file;
      Test_without_library;
      Test_suite_not_included;
      Missing_log_source;
    ];
  map

(* Derive 'all' list from the error code mappings to ensure consistency *)
let all =
  let codes =
    Hashtbl.fold
      (fun code issue_type acc -> (code, issue_type) :: acc)
      error_code_to_type []
  in
  (* Sort by error code to ensure consistent ordering *)
  codes |> List.sort (fun (a, _) (b, _) -> String.compare a b) |> List.map snd

(* Validation: ensure every issue type has a unique error code *)
let _ =
  let unique_codes = Hashtbl.length error_code_to_type in
  let total_types = List.length all in
  if unique_codes <> total_types then
    failwith
      (Printf.sprintf
         "Issue type validation failed: %d unique error codes but %d issue \
          types"
         unique_codes total_types)

(* Helper function to get issue type from error code *)
let of_error_code code =
  let upper_code = String.uppercase_ascii code in
  try Some (Hashtbl.find error_code_to_type upper_code) with Not_found -> None
