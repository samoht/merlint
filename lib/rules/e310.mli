(** E310: Value Naming Convention

    This rule ensures that value names follow OCaml naming conventions. Values
    should use snake_case naming. *)

val check :
  filename:string -> outline:Outline.t option -> Typedtree.t -> Issue.t list
(** [check ~filename ~outline typedtree] analyzes the typedtree to find values
    with names that don't follow snake_case convention. Returns a list of issues
    for values that violate the rule. *)
