(** E010: Deep Nesting

    This rule detects code with excessive nesting depth. Deep nesting makes code
    harder to read and understand. *)

type config = { max_nesting : int }

val check : Context.file -> Issue.t list
(** [check config browse_data] analyzes the browse data to find code with
    nesting depth exceeding the configured threshold. The configuration record
    contains max_nesting field (default: 3). Returns a list of issues for code
    that violates the rule. *)
