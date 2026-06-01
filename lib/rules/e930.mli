(** E930: I/O-free policy.

    The org standardises on Eio, so {b no} opam package may depend on lwt, miou,
    or mirage runtimes. Packages tagged I/O-free -- any [codec.*] topic (the
    encoding kind) or the top-level [protocol] tag (a state machine wrapping a
    wire codec) -- face an additional rule: a pure I/O-free package (sans the
    [eio] tag) must also avoid [eio*], [unix], and ambient-clock deps; and such
    packages expose Bytesrw Reader/Writer in the main library rather than
    shipping a separate [<pkg>_bytesrw] sub-library. The rule checks [depends:]
    in the opam file and every [(library ...)] under the package directory. *)

val rule : Rule.t
(** The E930 rule definition. *)
