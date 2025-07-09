(** Violation types and formatting

    This module defines the types for all possible issues that merlint can
    detect, along with functions to format them for output. *)

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

val pp : t Fmt.t
(** Pretty-printer for issues *)

val format : t -> string
(** [Deprecated] Use pp instead *)

val get_issue_type : t -> string
(** Get a string identifier for the issue type *)

val find_grouped_hint : string -> t list -> string option
(** Get a helpful hint for a group of issues of the same type *)

val compare : t -> t -> int
(** Compare issues by priority, then by location *)
