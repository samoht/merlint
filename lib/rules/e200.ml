(** E200: Outdated Str Module *)

let check (ctx : Context.file) =
  let ast_data = Context.ast ctx in

  (* Check identifiers for Str module usage *)
  Traverse.check_module_usage ast_data.identifiers "Str" (fun ~loc ->
      Issue.v ~loc ())

let pp ppf () =
  Fmt.pf ppf "Usage of deprecated Str module detected - use Re module instead"

let rule =
  Rule.v ~code:"E200" ~title:"Outdated Str Module" ~category:Style_modernization
    ~hint:
      "The Str module is outdated and has a problematic API. Use the Re module \
       instead for regular expressions. Re provides a better API, is more \
       performant, and doesn't have global state issues."
    ~examples:[] ~pp (File check)
