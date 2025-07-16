(** E335: Used Underscore-Prefixed Binding

    This rule detects bindings prefixed with underscore (indicating they should
    be unused) that are actually used in the code. *)

val check : Context.file -> Issue.t list
(** [check AST] analyzes the AST to find underscore-prefixed bindings that are
    actually used. Returns a list of issues for bindings that violate the rule.
*)
