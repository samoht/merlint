(** E325: Function Naming Convention

    This rule ensures that functions follow naming conventions:
    - get_* functions should not return option types
    - find_* functions should return option types *)

val check : Context.t -> Issue.t list
(** [check ~filename ~outline] analyzes the outline to find functions with names
    that don't match their return types. Returns a list of issues for functions
    that violate the rule. *)
