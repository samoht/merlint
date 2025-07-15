(** E320: Long Identifier Names

    This rule detects identifiers with too many underscores (more than 4), which
    makes them hard to read. *)

val check : Typedtree.t -> Issue.t list
(** [check typedtree] analyzes the typedtree to find identifiers with too many
    underscores. Returns a list of issues for identifiers that violate the rule.
*)
