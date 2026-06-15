(** E953: Encoding verb vocabulary.

    A data-codec package (tagged [codec]) exposes its top-level entry points
    from the ocaml-encodings six-verb surface -- [of_string] / [to_string] /
    [of_reader] / [to_writer] for I/O, [decode] / [encode] over the AST -- each
    [of_]/[decode] with an [_exn] twin, never a ['] variant. This rule flags a
    value in such a package's top-level module (the [foo.ml] of library [foo])
    whose name is an anti-pattern synonym of one of those verbs: bare [parse] /
    [from_string] / [unmarshal] -> [of_string], [print] / [unparse] / [marshal]
    -> [to_string], [read] / [input] -> [of_reader], [write] / [output] ->
    [to_writer]. The prefixed [parse_*] / [print_*] helpers are internal and are
    left alone; only the bare synonyms are rejected. The codec/AST layering is
    E945; the protocol verb vocabulary is E948. *)

val rule : Rule.t
(** The E953 rule definition. *)
