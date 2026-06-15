(** E951: Exhaustive message match.

    Flags, in a state-machine module (see {!Protocol_modules}), a [match] over
    the protocol message type with a wildcard arm that silently accepts an
    unexpected message (returns a normal value rather than an [Error]). A
    protocol transition rejects an unexpected message at the value level
    ([Error _]) or enumerates every message constructor. See E946-E950 and
    E952. *)

val rule : Rule.t
(** The E951 rule definition. *)
