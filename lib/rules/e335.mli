(** E335: Used Underscore-Prefixed Binding

    This rule detects bindings prefixed with underscore (indicating they should
    be unused) that are actually used in the code. *)

val check : Typedtree.t -> Issue.t list
(** [check typedtree] analyzes the typedtree to find underscore-prefixed
    bindings that are actually used. Returns a list of issues for bindings that
    violate the rule. *)
