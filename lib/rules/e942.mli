(** E942: Disallowed library dependency.

    Flags any package that depends on a name listed in [disallowed_libraries] in
    [merlint.toml] -- whether through a [(libraries ...)] field it owns (in a
    library, executable, or test) or through its opam [depends:]. The list is
    empty by default and read from the project root. The build-level companion
    to E221, which bans module use in source. *)

val rule : Rule.t
(** The E942 rule definition. *)
