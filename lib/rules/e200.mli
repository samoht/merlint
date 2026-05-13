(** E200: Outdated Str Module

    This rule detects usage of the outdated Str module for regular expressions.
    The Re module is preferred for its better API and performance. *)

val rule : Rule.t
(** [rule] is the E200 rule definition. *)
