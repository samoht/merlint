(** E616: Use failf instead of fail (Fmt.str

    This rule detects usage of Alcotest.fail (Fmt.str ...) or fail (Fmt.str ...)
    in test files and suggests using Alcotest.failf or failf instead. *)

val rule : Rule.t
(** The E616 rule definition *)
