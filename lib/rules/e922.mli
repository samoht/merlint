(** E922: Package-less MDX stanza in multi-package project.

    In a multi-package dune project, [(mdx ...)] stanzas should carry an
    explicit [(package PKG)] field. Dune already attaches MDX checks to the
    directory's [runtest] alias; the package field records which package owns
    that documentation check and makes project-index attribution deterministic.
*)

val rule : Rule.t
(** The E922 rule definition. *)
