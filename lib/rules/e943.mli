(** E943: Misclassified test / dev dependency

    A package's runtime [depends:] entry that's only reached through test-scope
    or dev-scope stanzas should carry an appropriate filter: [{with-test}] for
    [(test ...)] / runtest-attached executables, or [{with-dev-setup}] for
    private executables not attached to runtest (generators, benchmarks). *)

val rule : Rule.t
(** [rule] is the E943 rule definition. *)
