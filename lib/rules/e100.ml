(** E100: No Obj.magic *)

(* Match the fully-resolved Stdlib path. Requires typedtree-level dump;
   parsetree fallback would produce false negatives (a local Obj module
   would be indistinguishable from the real one), so we skip the file
   when resolution is unavailable rather than guess. *)
let check ctx =
  match File_view.resolved_identifiers (Context.view ctx) with
  | None -> []
  | Some identifiers ->
      List.filter_map
        (fun ident ->
          if
            not
              (File_view.Reference.matches_path ident
                 [ "Stdlib"; "Obj"; "magic" ])
          then None
          else
            match File_view.Reference.loc ident with
            | Some loc -> Some (Issue.v ~loc ())
            | None -> None)
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
