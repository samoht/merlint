(** E320: Long Identifier Names

    This rule detects identifiers with too many underscores (more than 4), which
    makes them hard to read. *)

val rule : Rule.t
(** The E320 rule definition *)
