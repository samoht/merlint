(** E945: AST/codec layering.

    One layering for data codecs (ocaml-encodings) and wire protocols
    (ocaml-protocols): the AST is the base (named [Value] for data, [Message]
    for a protocol) and the typed [Codec] depends on it, never the reverse. This
    rule flags an AST module ([value.ml] or [message.ml], paired with a sibling
    [codec.ml]) that references its [Codec] module. Dependency order only; which
    parser the codec is built on (core, ocaml-wire, ...) is unconstrained. *)

val rule : Rule.t
(** The E945 rule definition. *)
