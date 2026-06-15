(** E951: Exhaustive message match.

    Flags, in a state-machine module (see {!Protocol_modules}), a [match] over
    the protocol message type whose catch-all arm silently accepts the
    unexpected message -- its body returns a normal value (an [Ok], a state,
    [()]) rather than rejecting it. A catch-all that rejects ([| _ -> Error _],
    [| s -> Error (`Unexpected s)]) is correct and not flagged. The silent
    accept is the FREAK/SKIP-class bug. See E946-E950 and E952. *)

val rule : Rule.t
(** The E951 rule definition. *)
