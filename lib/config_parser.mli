(** Configuration file parser for [merlint.toml] (TOML 1.1). *)

type parsed_config = {
  settings : (string * string) list;
  exclusions : Rule_config.t;
}
(** [parsed_config] represents parsed configuration data. *)

val parse : ?config_dir:string -> string -> parsed_config
(** [parse ?config_dir content] parses TOML content. [config_dir] is attached to
    rule exclusions so file globs can be matched relative to the configuration
    file that declared them. Raises [Failure] on a malformed document. *)

val parse_file : string -> parsed_config option
(** [parse_file path] loads and parses a configuration file at the given path.
    Returns [None] when the file does not exist. *)
