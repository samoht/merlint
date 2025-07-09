(** Format rules to check project formatting configuration *)

val check : string -> string list -> Issue.t list
(** [check project_root files] checks formatting rules for the given files *)
