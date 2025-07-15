(** E350: Boolean Blindness

    This rule detects functions with 2 or more boolean parameters, which can
    lead to confusion about argument order and meaning. *)

val check :
  filename:string -> outline:Outline.t option -> Typedtree.t -> Issue.t list
(** [check ~filename ~outline typedtree] analyzes the typedtree to find
    functions with multiple boolean parameters. Returns a list of issues for
    functions that violate the rule. *)
