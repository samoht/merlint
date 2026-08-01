(** E610: Test Without Library

    This rule ensures that test files have corresponding library modules.
    Orphaned test files should be removed or their library modules should be
    created.

    A module defined inside another compilation unit has no source file of its
    own, so the only evidence it exists is a reference in a library typedtree. A
    library source whose [.cmt] or [.cmti] no longer describes it therefore
    withholds references, and an absence read off the remainder is a guess. The
    finding says which reading it is: an unqualified absence when every library
    source was read, and the stale artefact with both possibilities otherwise.
*)

val rule : Rule.t
(** [rule] is the E610 rule definition. *)
