(** Centralized configuration for all merlint rules *)

type t = {
  (* Complexity rules *)
  max_complexity : int;
  max_function_length : int;
  max_nesting : int;
  (* Naming rules *)
  max_underscores_in_name : int;
  min_name_length_for_underscore_check : int;
  (* Style rules *)
  allow_obj_magic : bool;
  allow_str_module : bool;
  allow_catch_all_exceptions : bool;
  (* Format rules *)
  require_ocamlformat_file : bool;
  require_mli_files : bool;
}

val default : t
(** Default configuration with recommended settings *)

val to_complexity_config : t -> Cyclomatic_complexity.config
(** Convert to legacy complexity config format *)
