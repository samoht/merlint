(** E320: Long Identifier Names

    This rule detects identifiers with too many underscores (more than 4), which
    makes them hard to read. *)

val check : Context.file -> Issue.t list
(** [check AST] analyzes the AST to find identifiers with too many underscores.
    Returns a list of issues for identifiers that violate the rule. *)
