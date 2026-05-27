(** Tests for the Helpers module. *)

val rule_code : Merlint.Rule.t -> string
(** [rule_code rule] returns the lower-case identifier used to map [rule] to its
    cram fixture directory, for example [E505] becomes [e505]. *)

val cram_root : unit -> string
(** [cram_root ()] returns the merlint cram fixture root from either the source
    tree or the build/test working directory. *)

val fixture_dir : Merlint.Rule.t -> string
(** [fixture_dir rule] returns the directory containing the good and bad cram
    fixtures for [rule]. *)

val fixture_file : Merlint.Rule.t -> string -> string
(** [fixture_file rule name] returns a single fixture path inside
    {!fixture_dir}. *)

val fixture_suite : Merlint.Rule.t -> string * unit Alcotest.test_case list
(** [fixture_suite rule] builds the shared rule smoke-test suite. It checks that
    the rule exposes complete user-facing metadata and that its cram directory
    contains at least one good and one bad fixture. *)
