(** Warning silence detection

    This module checks for code that silences warnings instead of fixing them.
*)

val check : string list -> Issue.t list
(** [check files] checks files for silenced warnings *)
