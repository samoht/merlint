(** E948: Protocol verb vocabulary.

    Every protocol's state machine exposes the same small set of verbs, so a
    reviewer (and a state-machine learner) sees one uniform surface across the
    tree. The canonical verbs are [v], [client], [server], [handle], [incoming],
    [outgoing], [close], plus [timer] / [next_timeout] for time-driven
    transitions.

    This rule flags, in a state-machine module (the closed role vocabulary --
    see {!Protocol_modules}), a value whose name is an anti-pattern synonym of a
    canonical verb: the [parse_*] / [process_*] / [eat_*] prefixes, and bare
    [send] / [recv] / [receive] / [read] / [write] / [emit] / [step] / [make] /
    [create] / [init] / [shutdown] / [disconnect] (and friends). Each maps to a
    canonical verb.

    A distinct concept keeps its own descriptive name: [send_window] (a
    flow-control credit, not byte output) and [feed ~rx] (the borrowed-ring
    verb) are prefixed/specific, not bare synonyms, so they are left alone. *)

module FV = File_view

type payload = { module_ : string; verb : string; canonical : string }

(* Bare anti-pattern verb names, each mapped to its canonical replacement. *)
let bare_synonyms =
  [
    ("send", "outgoing");
    ("write", "outgoing");
    ("emit", "outgoing");
    ("transmit", "outgoing");
    ("output", "outgoing");
    ("recv", "handle");
    ("receive", "handle");
    ("read", "handle");
    ("parse", "handle");
    ("process", "handle");
    ("eat", "handle");
    ("step", "handle");
    ("dispatch", "handle");
    ("consume", "handle");
    ("ingest", "handle");
    ("make", "v");
    ("create", "v");
    ("init", "v");
    ("shutdown", "close");
    ("disconnect", "close");
    ("teardown", "close");
  ]

(* Prefixes the protocols skill rejects outright. *)
let banned_prefixes =
  [ ("parse_", "handle"); ("process_", "handle"); ("eat_", "handle") ]

let canonical_of name =
  let n = String.lowercase_ascii name in
  match List.assoc_opt n bare_synonyms with
  | Some c -> Some c
  | None ->
      List.find_map
        (fun (p, c) -> if String.starts_with ~prefix:p n then Some c else None)
        banned_prefixes

let check (ctx : Context.project) (m : Protocol_modules.machine_module) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        FV.all_items view
        |> List.filter_map (fun item ->
            match FV.Item.kind item with
            | FV.Item.Value -> (
                let name = FV.Item.name item in
                match canonical_of name with
                | Some canonical ->
                    Some
                      (Issue.v ~loc:(FV.Item.loc item)
                         { module_ = m.module_name; verb = name; canonical })
                | None -> None)
            | _ -> None)

let enumerate ctx = Protocol_modules.protocol_machine_modules ctx

let pp ppf { module_; verb; canonical } =
  Fmt.pf ppf
    "%s.%s is not a canonical protocol verb. Rename it to %s; the state \
     machine uses the canonical vocabulary (v / client / server / handle / \
     incoming / outgoing / close), and the parse_* / process_* / eat_* and \
     bare send / recv / make synonyms are rejected."
    (String.capitalize_ascii module_)
    verb canonical

let rule =
  Rule.v ~code:"E948" ~title:"Protocol verb vocabulary"
    ~category:Rule.Naming_conventions
    ~hint:
      "A state-machine module uses the canonical verb vocabulary (v, client, \
       server, handle, incoming, outgoing, close, timer, next_timeout). The \
       anti-pattern synonyms parse_* / process_* / eat_* and bare send / recv \
       / receive / read / write / step / make / create / init / shutdown are \
       rejected -- each maps to a canonical verb. See E946 for the module, \
       E947 for immutable state, E949 for one machine per module."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
