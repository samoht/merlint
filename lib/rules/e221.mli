(** E221: Disallowed module.

    Flags any use of a module path listed in [disallowed_modules] in
    [merlint.toml]. The list is empty by default and accumulates from every
    [merlint.toml] between a file's directory and the workspace root, so a ban
    declared in a subtree applies only to files under it. Matching is on
    resolved typedtree paths: a configured entry matches a reference when its
    dotted path is a prefix of the reference's resolved path, and a local module
    shadowing the banned name is not flagged. *)

val rule : Rule.t
(** The E221 rule definition. *)
