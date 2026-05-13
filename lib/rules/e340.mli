(** E340: Error Pattern Detection

    This rule detects Error constructors applied to Fmt.str results and suggests using
    error helper functions (err_foo) instead. *)

val rule : Rule.t
(** [rule] is the E340 rule definition. *)
