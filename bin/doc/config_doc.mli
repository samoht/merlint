(** Documentation for [merlint.toml]. *)

val man : Cmdliner.Manpage.block list
(** [man] is the cmdliner man section that drives [merlint help config]. *)

val examples : (string * string) list
(** [examples] is a list of [(label, toml-fragment)] pairs. Every example is
    valid TOML accepted by {!Config_parser.parse}. The config-doc test suite
    round-trips each one to keep the man page from drifting from the parser. *)
