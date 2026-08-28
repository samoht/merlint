(** E916: a [dune.lock] that does not honour a [dune-project] pin.

    A [(pin ...)] stanza names the exact revision its packages are built from.
    [dune pkg lock] does not fail when it cannot honour one: it resolves the
    package from somewhere else -- an overlay's copy, or the released archive
    that beat the pinned source on version ordering -- records that in the lock,
    and says nothing, so the build links source no declaration names. *)

val rule : Rule.t
(** [rule] is the E916 rule definition. *)
