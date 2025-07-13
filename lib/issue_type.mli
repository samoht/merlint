(** Types of issues that merlint can detect.

    This module defines all the different categories of code quality issues that
    merlint checks for, including complexity issues, style violations, naming
    convention problems, documentation gaps, and test coverage issues. *)

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

val error_code : t -> string
(** Get the error code for an issue type *)

val all : t list
(** All issue types *)
