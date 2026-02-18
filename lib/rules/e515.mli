(** E515: Tests and Libraries in Same Directory

    Detects when test and library stanzas in a dune file have files in the same
    directory. This often happens when using explicit (modules ...) to separate
    concerns within a single directory, which is discouraged. *)

val rule : Rule.t
