(** E101: No Marshal usage *)

type payload = { name : string }

let marshal_use ref_ =
  match File_view.Reference.prefix ref_ with
  | "Stdlib" :: "Marshal" :: _ ->
      Some ("Marshal." ^ File_view.Reference.base ref_)
  | [ "Stdlib" ] -> (
      match File_view.Reference.base ref_ with
      | ("output_value" | "input_value") as base -> Some base
      | _ -> None)
  | _ -> None

let check ctx =
  match File_view.resolved_identifiers (Context.view ctx) with
  | None -> []
  | Some identifiers ->
      List.filter_map
        (fun ref_ ->
          match (marshal_use ref_, File_view.Reference.loc ref_) with
          | Some name, Some loc -> Some (Issue.v ~loc { name })
          | _ -> None)
        identifiers

let pp ppf { name } =
  Fmt.pf ppf
    "Usage of %s detected - untyped (de)serialization bypasses the type system"
    name

let rule =
  Rule.v ~code:"E101" ~title:"No Marshal usage" ~category:Security_safety
    ~hint:
      "The Marshal module (and output_value/input_value) serializes values \
       without their type. A marshalled value carries no type information, so \
       Marshal.from_* can be read back at any type - including an abstract \
       type - forging values that violate the invariants their module \
       guarantees. Deserializing attacker-controlled data this way is also a \
       code-execution risk. Use a typed codec (a wire or cbor encoder and \
       decoder, or a hand-written printer and parser) instead. If a trusted \
       in-process boundary truly needs it, isolate it in one module and \
       document why."
    ~examples:
      [ Example.bad Examples.E101.bad_ml; Example.good Examples.E101.good_ml ]
    ~pp (File check)
