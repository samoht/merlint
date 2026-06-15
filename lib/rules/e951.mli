(** E951: Exhaustive message match.

    Flags, in a state-machine module (see {!Protocol_modules}), a [match] over
    the protocol message type that has a catch-all wildcard arm ([| _ -> ...]).
    The wildcard defeats the compiler's exhaustiveness check, so a message
    constructor added later silently falls through it; the arm body is
    irrelevant (even [| _ -> Error _] is flagged). Enumerate every constructor
    instead. The message-scoped sibling of OCaml's fragile-match warning. See
    E946-E950 and E952. *)

val rule : Rule.t
(** The E951 rule definition. *)
