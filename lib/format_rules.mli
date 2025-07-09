(** Format rules to check project formatting configuration *)

val check : string -> Issue.t list
(** [check project_root] checks formatting rules for the project *)

val check_with_files : string -> string list -> Issue.t list
(** [check_with_files project_root files] checks formatting rules only for the
    given files *)

val check_ocamlformat_exists : string -> Issue.t option
(** [check_ocamlformat_exists project_root] checks if .ocamlformat file exists
*)
