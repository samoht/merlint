(** E954: Protocol state machine entry points.

    A protocol's state machine is found through a uniform surface: it is built
    by a constructor and stepped by one inbound verb. The constructor is [v] (or
    a role constructor: [client] / [server] / [sender] / [receiver] /
    [initiator] / [responder] / [requester]), and the inbound transition is
    [incoming]. E948 rejects the synonyms; this rule requires the canonical
    entry points to exist in the first place, so a reviewer (and a state-machine
    learner) can always locate where the machine is built and where it consumes
    a peer message.

    This rule flags, in a state-machine module (the closed role vocabulary --
    see {!Protocol_modules}), the absence of [incoming] and the absence of any
    constructor. A module missing both produces two issues; a module with both
    is clean. See E946 (the module is present), E948 (verb names), E950
    (transitions are total). *)

module FV = File_view

type payload = { module_ : string; missing : string }

let constructors =
  [
    "v";
    "client";
    "server";
    "sender";
    "receiver";
    "initiator";
    "responder";
    "requester";
  ]

let check (ctx : Context.project) (m : Protocol_modules.machine_module) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        let names =
          FV.typed_all_items view
          |> List.filter_map (fun item ->
              match FV.Item.kind item with
              | FV.Item.Value -> Some (FV.Item.name item)
              | _ -> None)
        in
        let loc = Location.in_file (Context.string_of_path m.file) in
        let issue missing = Issue.v ~loc { module_ = m.module_name; missing } in
        let missing_incoming =
          if List.mem "incoming" names then [] else [ issue "incoming" ]
        in
        let missing_constructor =
          if List.exists (fun c -> List.mem c names) constructors then []
          else [ issue "constructor" ]
        in
        missing_incoming @ missing_constructor

let enumerate ctx = Protocol_modules.protocol_machine_modules ctx

let pp ppf { module_; missing } =
  let m = String.capitalize_ascii module_ in
  match missing with
  | "incoming" ->
      Fmt.pf ppf
        "%s exposes no `incoming` verb. A protocol state machine's inbound \
         transition is named incoming (t -> input -> ...); add it so the \
         machine's entry point is findable."
        m
  | _ ->
      Fmt.pf ppf
        "%s exposes no constructor. A protocol state machine is built by v (or \
         a role constructor: client / server / sender / receiver / initiator / \
         responder / requester)."
        m

let rule =
  Rule.v ~code:"E954" ~title:"Protocol state machine entry points"
    ~category:Rule.Project_structure
    ~hint:
      "A protocol's state machine exposes both an inbound verb (incoming) and \
       a constructor (v, or a role constructor: client / server / sender / \
       receiver / initiator / responder / requester), so a reviewer can always \
       find where the machine is built and where it steps. See E946 for the \
       module being present, E948 for the verb names, E950 for total \
       transitions."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
