(** E946: Protocol state machine.

    A protocol package (tagged [protocol]) is a codec plus an I/O-free state
    machine. This rule flags a protocol-tagged package whose libraries expose no
    state-machine module -- neither a [State] module (symmetric) nor a complete
    role pair (asymmetric: [Client]/[Server], [Sender]/[Receiver],
    [Initiator]/[Responder], [Requester]/[Responder]). A package whose machines
    use other names lists them in [allowed_states] in its [merlint.toml]; that
    list replaces the default vocabulary, so the package then satisfies this
    rule by exposing one of the declared modules instead. The role vocabulary
    lives in {!Protocol_modules}. Purity of the core is E930; AST/codec layering
    is E945; the state-machine invariants are E947/E948/E949. *)

val rule : Rule.t
(** The E946 rule definition. *)
