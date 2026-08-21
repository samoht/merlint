(** E947: Immutable protocol state.

    A protocol's state machine is a pure value: [handle s msg] returns a new
    state and never mutates [s] under another caller's feet. That property is
    what makes the machine deterministic, replayable, and L*-learnable. A
    [mutable] field, or a [bytes] / [ref] / [array] anywhere in the state type,
    is a mutable buffer hiding in the state and breaks it.

    This rule flags, in a state-machine module (the closed role vocabulary --
    see {!Protocol_modules}), any type declaration with a [mutable] field or a
    field/alias whose reachable type is [bytes] / [Bytes.t] / [ref] / [array] /
    [Bigarray]. Genuine mutable scratch (a decrypt ring, a reused buffer) is
    passed into the transition as a borrowed [~rx] argument or lives in the I/O
    adapter -- never in the state module. Payloads stay immutable [string].

    Constructor arguments carrying a forbidden type directly (e.g.
    [Sending of bytes]) are not inspected here; in practice a phase constructor
    carries a named record whose fields this rule does check. *)

module FV = File_view

type reason = Mutable | Forbidden_type of string
type payload = { module_ : string; offender : string; reason : reason }

(* The mutable named type constructors the immutable state must not reach. *)
let forbidden_constr (n : FV.Name.t) =
  let base = String.lowercase_ascii (FV.Name.base n) in
  let prefix = List.map String.lowercase_ascii (FV.Name.prefix n) in
  match base with
  | "bytes" | "ref" | "array" -> Some base
  | "t" when List.mem "bytes" prefix -> Some "bytes"
  | "t" when List.mem "bigarray" prefix -> Some "bigarray"
  | _ when List.mem "bigarray" prefix -> Some "bigarray"
  | _ -> None

let forbidden_in_type ty =
  List.find_map forbidden_constr (FV.Type_view.constrs ty)

(* Issues from a single field: its [mutable] flag, then a forbidden field type. *)
let field_issues ~module_ field =
  let name = FV.Item.name field in
  let mut =
    if FV.Item.is_mutable_field field then
      [ { module_; offender = name; reason = Mutable } ]
    else []
  in
  let typed =
    match FV.Item.type_sig field with
    | Some ty -> (
        match forbidden_in_type ty with
        | Some t -> [ { module_; offender = name; reason = Forbidden_type t } ]
        | None -> [])
    | None -> []
  in
  mut @ typed

let type_issues ~module_ item =
  let name = FV.Item.name item in
  (* A type alias / manifest can reach a forbidden type directly:
     [type buf = bytes]. *)
  let alias =
    match FV.Item.type_sig item with
    | Some ty -> (
        match forbidden_in_type ty with
        | Some t -> [ { module_; offender = name; reason = Forbidden_type t } ]
        | None -> [])
    | None -> []
  in
  let fields =
    FV.Item.children item
    |> List.concat_map (fun child ->
        match FV.Item.kind child with
        | FV.Item.Field -> field_issues ~module_ child
        | _ -> [])
  in
  alias @ fields

let issue_of ~loc payload = Issue.v ~loc payload

let check (ctx : Context.project) (m : Protocol_modules.machine_module) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        FV.typed_all_items view
        |> List.concat_map (fun item ->
            match FV.Item.kind item with
            | FV.Item.Type ->
                type_issues ~module_:m.module_name item
                |> List.map (fun p -> issue_of ~loc:(FV.Item.loc item) p)
            | _ -> [])

let enumerate ctx = Protocol_modules.protocol_machine_modules ctx

let pp ppf { module_; offender; reason } =
  match reason with
  | Mutable ->
      Fmt.pf ppf
        "%s.%s is a mutable field of the protocol state. Protocol state is \
         immutable; pass mutable scratch in as a borrowed ~rx argument or keep \
         it in the I/O adapter, never as a field of the state."
        (String.capitalize_ascii module_)
        offender
  | Forbidden_type t ->
      Fmt.pf ppf
        "%s.%s has type %s in the protocol state. %s is a mutable buffer; the \
         immutable state keeps payloads as string and pushes mutable scratch \
         to the I/O adapter (or a borrowed ~rx argument)."
        (String.capitalize_ascii module_)
        offender t t

let rule =
  Rule.v ~code:"E947" ~title:"Immutable protocol state"
    ~category:Rule.Project_structure
    ~hint:
      "A protocol's state machine is a pure value, so its state type carries \
       no mutable field and no bytes / ref / array. Mutable scratch (decrypt \
       ring, reused buffer, dynamic table) is passed in as a borrowed ~rx \
       argument or lives in the I/O adapter, never in the state. See E946 for \
       the state-machine module, E948 for verb names, E949 for one machine per \
       module."
    ~examples:[] ~pp
    (Project_units { enumerate; check })
