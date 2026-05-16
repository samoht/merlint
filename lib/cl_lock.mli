(** Global mutex serialising compiler-libs entry points.

    [Ocaml_parsing], [Ocaml_typing], and Merlin's Library backend share mutable
    globals (lexer state, environments, hashtables) that domains race on.
    Anything calling into those modules must run under {!with_lock}; parallel
    workers serialise on it but stay free to run pure rule logic concurrently.
*)

val with_lock : (unit -> 'a) -> 'a
(** [with_lock f] runs [f ()] holding the global compiler-libs mutex. *)
