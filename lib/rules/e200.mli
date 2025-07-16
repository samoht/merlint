(** E200: Outdated Str Module

    This rule detects usage of the outdated Str module for regular expressions.
    The Re module is preferred for its better API and performance. *)

val check : Context.file -> Issue.t list
(** [check AST] analyzes the AST to find usage of the Str module. Returns a list
    of issues for each usage found. *)
