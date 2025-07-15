(** Centralized rules coordinator for all merlint checks *)

type config = { merlint_config : Config.t; project_root : string }

val get_project_root : string -> string
(** [get_project_root file] finds the project root by looking for dune-project
*)

val default_config : string -> config
(** [default_config project_root] creates default configuration *)

val analyze_project :
  config -> string list -> Rule_filter.t option -> (string * Report.t list) list
(** [analyze_project config files rule_filter] analyzes all files in a project
    and returns categorized reports, optionally filtered by rule *)
