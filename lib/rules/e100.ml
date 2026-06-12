(** E100: No Obj usage *)

type payload = { member : string }

let obj_member ref_ =
  match File_view.Reference.prefix ref_ with
  | "Stdlib" :: "Obj" :: _ -> Some (File_view.Reference.base ref_)
  | _ -> None

let check ctx =
  match File_view.resolved_identifiers (Context.view ctx) with
  | None -> []
  | Some identifiers ->
      List.filter_map
        (fun ref_ ->
          match (obj_member ref_, File_view.Reference.loc ref_) with
          | Some member, Some loc -> Some (Issue.v ~loc { member })
          | _ -> None)
        identifiers

let pp ppf { member } =
  Fmt.pf ppf "Usage of Obj.%s detected - this is extremely unsafe" member

let rule =
  Rule.v ~code:"E100" ~title:"No Obj usage" ~category:Security_safety
    ~hint:
      "The Obj module bypasses OCaml's type system and is not part of the \
       language. Any use (Obj.magic, Obj.repr, Obj.obj, Obj.tag, ...) can \
       cause segmentation faults, data corruption, and unpredictable behavior. \
       Use proper type definitions, GADTs, or polymorphic variants instead. If \
       an unsafe boundary is truly unavoidable, isolate it in one module and \
       document why."
    ~examples:
      [ Example.bad Examples.E100.bad_ml; Example.good Examples.E100.good_ml ]
    ~pp (File check)
