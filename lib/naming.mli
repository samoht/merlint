(** Naming convention rules

    This module checks that OCaml code follows modern naming conventions. *)

val check :
  filename:string -> outline:Outline.t option -> Parsetree.t -> Issue.t list
(** [check ~filename ~outline parsetree] analyzes the parsetree and returns
    naming issues. If outline is provided, it will be used for function naming
    checks. *)
