(** Git working trees. *)

val main : Fpath.t -> Fpath.t option
(** [main dir] is the main working tree of the repository [dir] is a linked
    working tree of, and [None] when [dir] is not one, when it belongs to a bare
    repository, or when the link cannot be read.

    A linked working tree holds only what is committed, so the gitignored
    companions the main tree carries -- a local [_opam] switch above all -- are
    absent from it, and a build run there has no switch to resolve against. This
    is what names the tree whose switch it was branched from. *)
