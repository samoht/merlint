(** Configuration file parser for [merlint.toml] (TOML 1.1). *)

type parsed_config = {
  settings : (string * string) list;
  exclusions : Rule_config.t;
}
(** [parsed_config] represents parsed configuration data. *)

val parse : string -> parsed_config
(** [parse content] parses TOML content. Raises [Failure] on a malformed
    document. *)

val parse_file : string -> parsed_config option
(** [parse_file path] loads and parses a configuration file at the given path.
    Returns [None] when the file does not exist. *)
