(** E100: No Obj.magic *)

let is_obj_magic_ref ref_ =
  File_view.Reference.matches_path ref_ [ "Stdlib"; "Obj"; "magic" ]

let check ctx =
  match File_view.resolved_identifiers (Context.view ctx) with
  | None -> []
  | Some identifiers ->
      List.filter_map
        (fun ref_ ->
          if not (is_obj_magic_ref ref_) then None
          else
            Option.map
              (fun loc -> Issue.v ~loc ())
              (File_view.Reference.loc ref_))
        identifiers

let pp ppf () =
  Fmt.pf ppf "Usage of Obj.magic detected - this is extremely unsafe"

let rule =
  Rule.v ~code:"E100" ~title:"No Obj.magic" ~category:Security_safety
    ~hint:
      "Obj.magic completely bypasses OCaml's type system and is extremely \
       dangerous. It can lead to segmentation faults, data corruption, and \
       unpredictable behavior. Instead, use proper type definitions, GADTs, or \
       polymorphic variants. If you absolutely must use unsafe features, \
       document why and isolate the usage."
    ~examples:
      [ Example.bad Examples.E100.bad_ml; Example.good Examples.E100.good_ml ]
    ~pp (File check)
