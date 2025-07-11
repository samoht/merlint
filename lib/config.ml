(** Centralized configuration for all merlint rules *)

type t = {
  (* Complexity rules *)
  max_complexity : int;
  max_function_length : int;
  max_nesting : int;
  exempt_data_definitions : bool; (* Don't check length for pure data *)
  (* Naming rules *)
  max_underscores_in_name : int;
  min_name_length_underscore : int;
  (* Style rules *)
  allow_obj_magic : bool;
  allow_str_module : bool;
  allow_catch_all_exceptions : bool;
  (* Format rules *)
  require_ocamlformat_file : bool;
  require_mli_files : bool;
}

let default =
  {
    (* Complexity defaults *)
    max_complexity = 10;
    max_function_length = 50;
    max_nesting = 3;
    exempt_data_definitions = true;
    (* Naming defaults *)
    max_underscores_in_name = 3;
    min_name_length_underscore = 5;
    (* Style defaults - all issues enabled *)
    allow_obj_magic = false;
    allow_str_module = false;
    allow_catch_all_exceptions = false;
    (* Format defaults *)
    require_ocamlformat_file = true;
    require_mli_files = true;
  }

(* Convert to legacy config formats for existing modules *)
let to_complexity_config (config : t) =
  Complexity.
    {
      max_complexity = config.max_complexity;
      max_function_length = config.max_function_length;
      max_nesting = config.max_nesting;
    }
