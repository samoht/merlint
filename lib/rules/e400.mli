(** E400: Missing MLI Documentation

    This rule ensures that .mli files have proper documentation. MLI files
    should start with a documentation comment. *)

val check : Context.t -> Issue.t list
(** [check files] analyzes the list of files to find .mli files without proper
    documentation. Returns a list of issues for files that violate the rule. *)
