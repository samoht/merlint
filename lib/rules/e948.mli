(** E948: Protocol verb vocabulary.

    Flags, in a state-machine module (the closed role vocabulary -- see
    {!Protocol_modules}), a value whose name is an anti-pattern synonym of a
    canonical protocol verb: the [parse_*] / [process_*] / [eat_*] prefixes and
    bare [send] / [recv] / [receive] / [read] / [write] / [emit] / [step] /
    [make] / [create] / [init] / [shutdown] / [disconnect]. Each maps to a
    canonical verb ([v], [client], [server], [incoming], [outgoing], [close]).
    See E946 (the module), E947 (immutable state), E949 (one machine per
    module). *)

val rule : Rule.t
(** The E948 rule definition. *)
