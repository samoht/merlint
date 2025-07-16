(** E615: Test Suite Not Included

    This rule ensures that test suites are properly included in test runners.
    All test modules should be included in the main test runner. *)

val check : Context.t -> Issue.t list
(** [check dune_data files] checks if test suites are included in test runners.
    Returns a list of issues for excluded test suites. *)
