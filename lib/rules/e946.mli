(** E946: Protocol layering.

    The ocaml-protocols layering is one-way [codec <- message]: [codec.ml] is
    the AST-free combinator base and [message.ml] builds its codecs from it.
    This rule flags a [codec.ml] (paired with a sibling [message.ml]) that
    references its [Message] module, which inverts that order. It is the mirror
    of E945 (encodings, where [value.ml] is the base). Dependency order only. *)

val rule : Rule.t
(** The E946 rule definition. *)
