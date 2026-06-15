(** E946: Protocols expose a state machine.

    A protocol package (tagged [protocol]) is a codec plus an I/O-free state
    machine -- that state machine is the package's primary concern. It must live
    in a module named from the closed role vocabulary: [State] (symmetric), or a
    complete role pair for asymmetric protocols where who-initiates matters
    ([Client]/[Server], [Sender]/[Receiver], [Initiator]/[Responder],
    [Requester]/[Responder]). A protocol package with no such module is missing
    its defining layer (it is then only a codec, and should drop the [protocol]
    tag, or it has hidden the state machine somewhere unfindable).

    A package whose machines use names outside this vocabulary lists their
    module basenames in [allowed_states] in its [merlint.toml]. That list
    replaces the default vocabulary: the state machines are then exactly the
    declared modules, and exposing one of them satisfies this rule.

    This checks the module is present; that it is *pure* (no eio/lwt/unix in the
    core library) is E930, that the AST does not depend on the codec is E945,
    and the state-machine invariants are E947 (immutable state), E948 (verb
    vocabulary), and E949 (one machine per module). The role vocabulary lives in
    {!Protocol_modules}, kept in sync with the ocaml-protocols skill. *)

module P = Project_index.Package

type payload = { package : string }

let opam_path pkg =
  match P.opam_path pkg with
  | Some path -> Fpath.to_string (Loc.current_dir_relative path)
  | None -> P.name pkg ^ ".opam"

let check_package pkg =
  if
    (not (Protocol_modules.is_protocol_pkg pkg))
    || Protocol_modules.exposes_state_machine pkg
  then []
  else
    let opam = opam_path pkg in
    [ Issue.v ~loc:(Location.in_file opam) { package = P.name pkg } ]

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.concat_map check_package

let pp ppf { package } =
  Fmt.pf ppf
    "%s is tagged protocol but exposes no state-machine module. A protocol is \
     a codec plus an I/O-free state machine; put it in a State module (or a \
     role pair -- Client/Server, Sender/Receiver, ... -- for asymmetric \
     protocols)."
    package

let rule =
  Rule.v ~code:"E946" ~title:"Protocol state machine"
    ~category:Rule.Project_structure
    ~hint:
      "A protocol package (tagged protocol) is a codec plus an I/O-free state \
       machine. Expose that state machine as a State module, or a role pair \
       (Client/Server, Sender/Receiver, Initiator/Responder, \
       Requester/Responder) for asymmetric protocols. A package whose machines \
       use other names lists them in allowed_states in merlint.toml, which \
       replaces the default vocabulary. Purity of the core is E930; AST/codec \
       layering is E945."
    ~examples:[] ~pp (Project check)
