(** Test suite for the Naming module.

    Tests the conversion functions for different naming conventions including
    Snake_case for modules/variants and lowercase_snake_case for values/types.
*)

val suite : string * unit Alcotest.test_case list
(** [suite] is the test suite for Naming module. *)
