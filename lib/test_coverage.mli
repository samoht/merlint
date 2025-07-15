(** Legacy test coverage module - all checks have been moved to rules/*.ml

    @deprecated
      Use individual rule modules instead:
      - E605: Missing test file
      - E610: Test without library
      - E615: Test suite not included *)

val check_test_coverage : Dune.describe -> string list -> Issue.t list
(** @deprecated This function delegates to E605.check and E610.check *)

val check_test_runner_completeness :
  Dune.describe -> string list -> Issue.t list
(** @deprecated This function delegates to E615.check *)
