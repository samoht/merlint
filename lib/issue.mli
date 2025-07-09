(** Violation types and formatting

    This module defines the types for all possible violations that merlint can
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

val format : t -> string
