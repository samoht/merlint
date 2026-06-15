(** E950: Total protocol transitions.

    Flags, in a state-machine module (see {!Protocol_modules}), a call to
    [raise], [raise_notrace], [failwith], or [invalid_arg], and any [assert]
    (including [assert false]). A protocol's state machine is total: it rejects
    bad input by returning an [Error] and makes unreachable cases unreachable in
    the type, never raising at runtime. See E946-E949 for the rest of the
    protocol shape. *)

val rule : Rule.t
(** The E950 rule definition. *)
