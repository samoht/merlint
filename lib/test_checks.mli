(** Test file convention checks

    This module checks that test files follow proper conventions. *)

val check : string list -> Issue.t list
(** [check files] checks test files for convention issues *)
