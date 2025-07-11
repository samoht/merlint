(** Naming convention rules

    This module checks that OCaml code follows modern naming conventions. *)

val check :
  filename:string -> outline:Outline.t option -> Typedtree.t -> Issue.t list
(** [check ~filename ~outline typedtree] analyzes the typedtree and returns
    naming issues. If outline is provided, it will be used for function naming
    checks. *)
