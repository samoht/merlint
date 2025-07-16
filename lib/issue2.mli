(** Issue types for the new self-contained rule design *)

(** Rule identifier - a proper type instead of string codes *)
type rule_id =
  | Complexity
  | Function_length
  | Deep_nesting
  | Obj_magic
  | Catch_all_exception
  | Silenced_warning
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
  | Missing_log_source
  | Test_exports_module
  | Missing_test_file
  | Test_without_library
  | Test_suite_not_included

(** Issue data types - specific data for each issue *)
type data =
  | Complexity_exceeded of {
      name : string;
      complexity : int;
      threshold : int;
    }
  | Function_too_long of {
      name : string;
      length : int;
      threshold : int;
    }
  | No_obj_magic
  | Missing_mli_doc of { module_name : string; file : string }
  | Missing_value_doc of { value_name : string }
  | Bad_doc_style of {
      value_name : string;
      message : string;
    }
  | Bad_variant_naming of {
      variant : string;
      expected : string;
    }
  | Bad_module_naming of {
      module_name : string;
      expected : string;
    }
  | Bad_value_naming of {
      value_name : string;
      expected : string;
    }
  | Bad_type_naming of {
      type_name : string;
      message : string;
    }
  | Catch_all_exception
  | Use_str_module
  | Use_printf_module of { module_used : string }
  | Deep_nesting of {
      name : string;
      depth : int;
      threshold : int;
    }
  | Missing_standard_function of {
      module_name : string;
      type_name : string;
      missing : string list;
      file : string;
    }
  | Missing_ocamlformat_file
  | Missing_mli_file of {
      ml_file : string;
      expected_mli : string;
    }
  | Long_identifier_name of {
      name : string;
      underscore_count : int;
      threshold : int;
    }
  | Bad_function_naming of {
      function_name : string;
      suggestion : string;
    }
  | Redundant_module_name of {
      item_name : string;
      module_name : string;
      item_type : string; (* "function" or "type" *)
    }
  | Used_underscore_binding of {
      binding_name : string;
      usage_locations : Location.t list;
    }
  | Error_pattern of {
      error_message : string;
      suggested_function : string;
    }
  | Boolean_blindness of {
      function_name : string;
      bool_count : int;
      signature : string;
    }
  | Mutable_state of {
      kind : string; (* "ref", "mutable", "array" *)
      name : string;
    }
  | Test_exports_module_name of {
      filename : string;
      module_name : string;
    }
  | Silenced_warning of { warning_number : string }
  | Missing_test_file of {
      module_name : string;
      expected_test_file : string;
    }
  | Test_without_library of {
      test_file : string;
      expected_module : string;
    }
  | Test_suite_not_included of {
      test_module : string;
      test_runner_file : string;
    }
  | Missing_log_source of { module_name : string }

type t = {
  rule_id : rule_id;  (** Which rule found this issue *)
  location : Location.t option;  (** Location in source, if applicable *)
  data : data;  (** The specific payload *)
}
(** An issue found by a rule *)

val create : rule_id:rule_id -> ?location:Location.t -> data:data -> t
(** Create a new issue *)

val pp : t Fmt.t
(** Pretty-printer for issues - delegates to rule's format_issue *)

val compare : t -> t -> int
(** Compare issues for sorting *)

val priority : rule_id -> int
(** Get the priority of an issue by its rule ID *)

val rule_id_to_code : rule_id -> string
(** Convert a rule ID to its error code string (e.g., Complexity -> "E001") *)