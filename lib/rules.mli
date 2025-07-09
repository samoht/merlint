(** Centralized rules coordinator for all merlint checks *)

type config = { merlint_config : Config.t; project_root : string }

val find_project_root : string -> string
(** [find_project_root file] finds the project root by looking for dune-project *)

val default_config : string -> config
(** [default_config project_root] creates default configuration *)

val analyze_project : config -> string list -> (string * Report.t list) list
(** [analyze_project config files] analyzes all files in a project and returns
    categorized reports *)
