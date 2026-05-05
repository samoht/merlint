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
  allowed_words : string list;
      (** Words treated as atomic by naming rules (e.g. EdDSA, ECDSA). Parsed
          from [allowed_words] or [acronyms] in [.merlint]. *)
  topics : string list;
      (** Canonical opam tag vocabulary. Parsed from [topics] in [.merlint].
          When non-empty, E915 rejects any opam tag not in this list (plus the
          [org:*] namespace prefix which is always allowed). *)
  (* Style rules *)
  allow_obj_magic : bool;
  allow_str_module : bool;
  allow_catch_all_exceptions : bool;
  (* Format rules *)
  require_ocamlformat_file : bool;
  require_mli_files : bool;
  (* Rule exclusions *)
  exclusions : Rule_config.t;
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

val file : string -> string option
(** [file path] finds the outermost .merlint config file from the given path. *)

val load_from_path : string -> t
(** [load_from_path path] loads and merges all .merlint config files from [path]
    up to the workspace root. Settings from closer files override outer ones;
    rule exclusions accumulate. *)

val for_file : string -> t
(** [for_file file] returns the config that applies to [file], merging .merlint
    files from [file]'s directory up to the workspace root. Settings from closer
    files override outer ones; rule exclusions accumulate. *)
