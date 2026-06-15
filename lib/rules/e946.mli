(** E946: Protocol state machine.

    A protocol package (tagged [protocol]) is a codec plus an I/O-free state
    machine. This rule flags a protocol-tagged package whose libraries expose no
    state-machine module -- neither a [Protocol] module nor a [Client] /
    [Server] pair (the two shapes from the ocaml-protocols skill). Purity of the
    core is E930; AST/codec layering is E945. *)

val rule : Rule.t
(** The E946 rule definition. *)
