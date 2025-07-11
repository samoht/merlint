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
