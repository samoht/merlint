(** Test coverage checks

    This module ensures that library modules have corresponding test files and
    that all test suites are included in the test runner. *)

val check_test_coverage : Dune.describe -> string list -> Issue.t list
(** [check_test_coverage dune_describe files] checks that each library module
    has a corresponding test file and vice versa. Uses the parsed dune describe
    output to find library and test modules. *)

val check_test_runner_completeness :
  Dune.describe -> string list -> Issue.t list
(** [check_test_runner_completeness dune_describe files] checks that test.ml
    includes all test suites from test modules. *)
