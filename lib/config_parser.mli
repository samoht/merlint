(** Configuration file parser for .merlint files with YAML-like syntax. *)

type parsed_config = {
  settings : (string * string) list;
  exclusions : Rule_config.t;
}
(** [parsed_config] represents parsed configuration data. *)

val parse : string -> parsed_config
(** [parse content] parses configuration content and returns parsed data. *)

val parse_file : string -> parsed_config option
(** [parse_file path] loads and parses a configuration file at the given path.
*)
