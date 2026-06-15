(** E949: One state machine per module.

    Flags a state-machine module file (see {!Protocol_modules}) that defines
    more than one state-machine [type t] -- a record or variant [t] at the top
    level or inside a nested module. An asymmetric protocol splits each role
    into its own top-level module from the role vocabulary ([Client]/[Server],
    [Sender]/[Receiver], ...), never nested machines in one file. See E946 (the
    module), E947 (immutable state), E948 (verb names). *)

val rule : Rule.t
(** The E949 rule definition. *)
