(** Shared protocol state-machine vocabulary, used by E946-E949.

    A protocol's state machine lives in a module named from a closed vocabulary:
    [State] (symmetric, one role) or a role name (asymmetric). The same
    vocabulary is documented in the ocaml-protocols skill's "role vocabulary"
    section; the two are kept in sync.

    A package whose machines do not fit the vocabulary (e.g. a CFDP
    Class-1/Class-2 sender and receiver) declares its state-module basenames in
    [allowed_states] in its [merlint.toml]. That list does not extend the
    vocabulary -- it {e replaces} it: when set, the state machines are exactly
    the declared modules, and [State] and the role names are no longer
    recognised for that package. *)

val role_pairs : (string * string) list
(** The recognised complementary role pairs for asymmetric protocols:
    [Client]/[Server], [Sender]/[Receiver], [Initiator]/[Responder],
    [Requester]/[Responder]. *)

val roles : string list
(** The flattened, deduplicated role-module basenames (lowercased). *)

val is_state_machine_name : string -> bool
(** [is_state_machine_name b] is [true] when module basename [b] (any case, with
    or without extension) is in the default state-machine vocabulary: [state] or
    a role name. This predicate is vocabulary-only; per-package [allowed_states]
    overrides are applied by {!state_machine_modules}. *)

val is_protocol_pkg : Project_index.Package.t -> bool
(** [is_protocol_pkg p] is [true] when [p] is tagged [protocol] and is not an
    [eio] adapter (the adapter wires the I/O-free core into I/O). *)

val exposes_state_machine : Project_index.Package.t -> bool
(** [exposes_state_machine p] is [true] when [p] exposes a state machine. When
    [p]'s [allowed_states] is set, that is true iff one of those declared
    modules is present; otherwise it is true for a [State] module or a complete
    role pair. E946's predicate. *)

type machine_module = {
  package : string;  (** The owning package name. *)
  module_name : string;  (** The lowercased module basename (e.g. ["state"]). *)
  file : Context.path;  (** The resolved [.ml] source path. *)
}
(** A state-machine module's implementation file. *)

val state_machine_modules :
  Context.project -> Project_index.Package.t -> machine_module list
(** [state_machine_modules ctx p] are [p]'s state-machine module [.ml] files: if
    [p] declares [allowed_states], exactly those modules; otherwise those whose
    basename is in the default vocabulary. *)

val protocol_machine_modules : Context.project -> machine_module list
(** [protocol_machine_modules ctx] are the state-machine modules of every
    [protocol]-tagged (non-[eio]) source package. The enumeration shared by
    E947/E948/E949. *)
