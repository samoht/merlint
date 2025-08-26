(** Centralized configuration for all merlint rules. *)

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

val default : t
(** [default] configuration with recommended settings. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are equal. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for the configuration. *)

(** Configuration file loading. *)

val load_from_path : string -> t
(** [load_from_path path] loads nearest config file. *)
