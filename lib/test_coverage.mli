(** Test coverage checks

    This module ensures that library modules have corresponding test files and
    that all test suites are included in the test runner. *)

val check_test_coverage : string -> string list -> Issue.t list
(** [check_test_coverage project_root files] checks that each library module has
    a corresponding test file and vice versa. Uses dune describe to find library
    modules. *)

val check_test_runner_completeness : string list -> Issue.t list
(** [check_test_runner_completeness files] checks that test.ml includes all test
    suites from test modules. *)
