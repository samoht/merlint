(** E617: Test Suite Naming Convention

    This rule checks that test suite names follow proper conventions:
    - Use lowercase snake_case naming
    - Match the test file name (test_foo.ml should have suite 'foo') *)

val rule : Rule.t
(** The E617 rule definition *)
