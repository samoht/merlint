(** E952: Result-returning transitions.

    A protocol transition returns its outcome as a value: a new state, the bytes
    to send, the events to surface, and -- on bad input -- an [Error]. A
    transition typed to return [unit] has nowhere to put any of that, so it must
    be mutating state in place and signalling failure by raising. That is the
    shape nqsb-tls (USENIX 2015) rejects: the transition is a pure
    [state -> input -> (state * out, error) result], never
    [state -> input -> unit].

    This rule flags, in a state-machine module (see {!Protocol_modules}), a
    transition verb ([handle], [incoming], [outgoing], [close], [timer], [tick])
    whose return type is [unit]. (Mutation-in-place is also caught by E947, and
    raising by E950; this rule pins the return shape itself.) *)

module FV = File_view

type payload = { module_ : string; fn : string }

let transitions = [ "handle"; "incoming"; "outgoing"; "close"; "timer"; "tick" ]

let returns_unit ty =
  match FV.Type_view.return_type ty with
  | Some rt -> FV.Type_view.is_unit rt
  | None -> false

let check (ctx : Context.project) (m : Protocol_modules.machine_module) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        FV.typed_all_items view
        |> List.filter_map (fun item ->
            match (FV.Item.kind item, FV.Item.type_sig item) with
            | FV.Item.Value, Some ty
              when List.mem (FV.Item.name item) transitions && returns_unit ty
              ->
                Some
                  (Issue.v ~loc:(FV.Item.loc item)
                     { module_ = m.module_name; fn = FV.Item.name item })
            | _ -> None)

let enumerate ctx = Protocol_modules.protocol_machine_modules ctx

let pp ppf { module_; fn } =
  Fmt.pf ppf
    "%s.%s returns unit. A protocol transition returns its outcome as a value \
     -- a new state, the bytes to send, the events, and an Error on bad input \
     -- so it returns a result, never unit (which forces mutation and \
     raising)."
    (String.capitalize_ascii module_)
    fn

let rule =
  Rule.v ~code:"E952" ~title:"Result-returning transitions"
    ~category:Rule.Project_structure
    ~hint:
      "A protocol transition (handle / incoming / outgoing / close / timer) \
       returns a result carrying the new state, output, events, and an Error \
       on bad input -- never unit, which forces in-place mutation and raising. \
       See E947 (immutable state) and E950 (total transitions) for the related \
       invariants."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
