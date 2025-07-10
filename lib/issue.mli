(** Violation types and formatting

    This module defines the types for all possible issues that merlint can
    detect, along with functions to format them for output. *)

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
  | Test_exports_module
  | Silenced_warning
  | Missing_test_file
  | Test_without_library
  | Test_suite_not_included

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

val pp : t Fmt.t
(** Pretty-printer for issues *)

val format : t -> string
(** [Deprecated] Use pp instead *)

val get_type : t -> issue_type
(** Get the issue type for an issue *)

val find_grouped_hint : issue_type -> t list -> string option
(** Get a helpful hint for a group of issues of the same type *)

val compare : t -> t -> int
(** Compare issues by priority, then by location *)

val priority : t -> int
(** Get the priority of an issue (1 = highest) *)

val equal : t -> t -> bool
(** Check if two issues are equal *)
