(** E200: Outdated Str Module *)

(* Match the fully-resolved Stdlib.Str prefix. Requires typedtree; on
   parsetree fallback we can't tell a local [Str] module from the real
   one, so skip rather than guess. *)
let from_stdlib_str ident =
  match File_view.Reference.prefix ident with
  | "Stdlib" :: "Str" :: _ -> true
  | _ -> false

let check (ctx : Context.file) =
  match File_view.resolved_identifiers (Context.view ctx) with
  | None -> []
  | Some identifiers ->
      List.filter_map
        (fun ident ->
          if not (from_stdlib_str ident) then None
          else
            match File_view.Reference.loc ident with
            | Some loc -> Some (Issue.v ~loc ())
            | None -> None)
        identifiers

let pp ppf () =
  Fmt.pf ppf "Usage of deprecated Str module detected - use Re module instead"

let rule =
  Rule.v ~code:"E200" ~title:"Outdated Str Module" ~category:Style_modernization
    ~hint:
      "The Str module is outdated and has a problematic API. Use the Re module \
       instead for regular expressions. Re provides a better API, is more \
       performant, and doesn't have global state issues."
    ~examples:
      [ Example.bad Examples.E200.bad_ml; Example.good Examples.E200.good_ml ]
    ~pp (File check)
