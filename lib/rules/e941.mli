(** E941: Missing runtime dependency

    A library used via a package's [(libraries ...)] resolves to an opam package
    that isn't declared in the package's runtime [depends:]. Without the
    declaration, [opam install] from a fresh switch fails for downstream users
    -- the local build only worked because the dep happened to be in the active
    switch. *)

val rule : Rule.t
(** [rule] is the E941 rule definition. *)
