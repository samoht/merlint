(** E945: Encoding layering.

    In the ocaml-encodings (jsont) model the dependency is one-way
    [codec -> value]: [codec.ml] holds [type value = Value.t] and the identity
    codec materialises the AST, while [value.ml] is the base layer. This rule
    flags a [value.ml] that references its sibling [Codec] module, which inverts
    that order. It checks dependency order only -- a format may keep its parser
    in [codec.ml] or in a dedicated parser/lexer engine. *)

val rule : Rule.t
(** The E945 rule definition. *)
