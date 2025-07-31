(** E619: Use Fmt.failwith instead of failwith (Fmt.str

    This rule detects usage of failwith (Fmt.str ...) and suggests using
    Fmt.failwith instead for more concise and readable code. *)

val rule : Rule.t
(** The E619 rule definition *)
