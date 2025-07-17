(** E340: Error Pattern Detection

    This rule detects usage of Error (Fmt.str ...) patterns and suggests using
    error helper functions (err_foo) instead. *)

val rule : Rule.t
(** The E340 rule definition *)
