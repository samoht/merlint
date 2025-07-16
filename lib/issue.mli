(** Violation types and formatting

    This module defines the types for all possible issues that merlint can
    detect, along with functions to format them for output.

    It also defines all the different categories of code quality issues that
    merlint checks for, including complexity issues, style violations, naming
    convention problems, documentation gaps, and test coverage issues. *)

(** Issue categories/kinds *)
type kind =
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

(** Concrete issue instances *)
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
  | Redundant_module_name of {
      item_name : string;
      module_name : string;
      location : Location.t;
      item_type : string; (* "function" or "type" *)
    }
  | Used_underscore_binding of {
      binding_name : string;
      location : Location.t;
      usage_locations : Location.t list;
    }
  | Error_pattern of {
      location : Location.t;
      error_message : string;
      suggested_function : string;
    }
  | Boolean_blindness of {
      function_name : string;
      location : Location.t;
      bool_count : int;
      signature : string;
    }
  | Mutable_state of {
      kind : string; (* "ref", "mutable", "array" *)
      name : string;
      location : Location.t;
    }
  | Test_exports_module_name of {
      filename : string;
      location : Location.t;
      module_name : string;
    }
  | Silenced_warning of { location : Location.t; warning_number : string }
  | Missing_test_file of {
      module_name : string;
      expected_test_file : string;
      location : Location.t;
    }
  | Test_without_library of {
      test_file : string;
      expected_module : string;
      location : Location.t;
    }
  | Test_suite_not_included of {
      test_module : string;
      test_runner_file : string;
      location : Location.t;
    }
  | Missing_log_source of { module_name : string; location : Location.t }

val pp : t Fmt.t
(** Pretty-printer for issues *)

val format : t -> string
(** [Deprecated] Use pp instead *)

val get_type : t -> kind
(** Get the issue type for an issue *)

val error_code : kind -> string
(** Get the error code for an issue type *)

val kind_of_error_code : string -> kind option
(** Get the issue type from an error code. Returns None if code is invalid *)

val all_kinds : kind list
(** All issue types, sorted by error code *)

val find_location : t -> Location.t option
(** Extract location from an issue *)

val get_description : t -> string
(** Get issue description without location prefix *)

val compare : t -> t -> int
(** Compare issues by priority, then by location *)

val priority : t -> int
(** Get the priority of an issue (1 = highest) *)

val equal : t -> t -> bool
(** Check if two issues are equal *)

exception Disabled of string
(** Exception raised when a rule is temporarily disabled or not yet implemented.
*)
