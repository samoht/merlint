(** Tests for Merlint probe event wrappers. *)

val suite : string * unit Alcotest.test_case list
(** [suite] verifies probe wrappers preserve user function results and errors.
*)
