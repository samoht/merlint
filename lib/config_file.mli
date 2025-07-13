(** Configuration file loading for merlint

    This module handles loading configuration from .merlintrc files. *)

val find_config_file : string -> string option
(** [find_config_file path] searches for a .merlintrc file starting from [path]
    and walking up the directory tree. Returns the path to the config file if
    found. *)

val load : string -> Config.t
(** [load path] loads configuration from the file at [path]. Returns default
    config if file cannot be read or parsed. *)

val load_from_path : string -> Config.t
(** [load_from_path path] finds and loads the nearest .merlintrc file starting
    from [path]. Returns default config if no config file is found. *)
