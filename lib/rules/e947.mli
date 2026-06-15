(** E947: Immutable protocol state.

    Flags, in a state-machine module (the closed role vocabulary -- see
    {!Protocol_modules}), any type declaration with a [mutable] field or a
    field/alias whose reachable type is [bytes] / [Bytes.t] / [ref] / [array] /
    [Bigarray]. A protocol's state machine is a pure value; mutable scratch is a
    borrowed [~rx] argument or lives in the I/O adapter, never in the state. See
    E946 (the module), E948 (verb names), E949 (one machine per module). *)

val rule : Rule.t
(** The E947 rule definition. *)
