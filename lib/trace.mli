(** Wall-time spans emitted as OCaml 5 [Runtime_events] user events.

    Enabled at runtime when the process starts with
    [OCAML_RUNTIME_EVENTS_START=1] or after a call to [Runtime_events.start ()].
    Otherwise the writes are cheap no-ops, so the instrumentation can stay live
    in production. *)

val span : string -> (unit -> 'a) -> 'a
(** [span name f] emits a [Begin] event before [f ()] and an [End] event after,
    even when [f] raises. *)

val rule_span : string -> (unit -> 'a) -> 'a
(** [rule_span code f] emits a span named [merlint.rule.<code>]. *)

val merlin_span : string -> (unit -> 'a) -> 'a
(** [merlin_span what f] emits a span named [merlint.merlin.<what>]. *)
