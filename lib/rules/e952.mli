(** E952: Result-returning transitions.

    Flags, in a state-machine module (see {!Protocol_modules}), a transition
    verb ([handle], [incoming], [outgoing], [close], [timer], [tick]) whose
    return type is [unit]. A protocol transition returns its outcome as a value
    -- a new state, output, events, and an [Error] on bad input -- never [unit].
    See E947 (immutable state) and E950 (total transitions). *)

val rule : Rule.t
(** The E952 rule definition. *)
