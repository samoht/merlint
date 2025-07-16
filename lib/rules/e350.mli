(** E350: Boolean Blindness

    This rule detects functions with 2 or more boolean parameters, which can
    lead to confusion about argument order and meaning. *)

val check : Context.t -> Issue.t list
(** [check ~filename ~outline AST] analyzes the AST to find functions with
    multiple boolean parameters. Returns a list of issues for functions that
    violate the rule. *)
