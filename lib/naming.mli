(** Naming convention rules

    This module checks that OCaml code follows modern naming conventions. *)

val check : Yojson.Safe.t -> Issue.t list
(** [check ast] analyzes the AST and returns naming issues. *)
