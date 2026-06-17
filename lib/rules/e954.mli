(** E954: Protocol state machine entry points.

    Flags, in a state-machine module (see {!Protocol_modules}), the absence of
    the inbound verb [incoming] and the absence of any constructor ([v], or a
    role constructor: [client] / [server] / [sender] / [receiver] / [initiator]
    / [responder] / [requester]). A protocol's state machine exposes both, so a
    reviewer can find where the machine is built and where it consumes a peer
    message. A module missing both produces two issues. See E946 (the module is
    present), E948 (verb names), E950 (transitions are total). *)

val rule : Rule.t
(** The E954 rule definition. *)
