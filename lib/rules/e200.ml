(** E200: Outdated Str Module *)

let check (ctx : Context.file) =
  let dump_data = Context.dump ctx in
  let filename = ctx.filename in

  (* Check identifiers for Str module usage *)
  (* In typedtree, we get ["Stdlib"; "Str"] or ["Str"]
     In parsetree, we get ["Str"] for Str.function_name *)
  Dump.check_module_usage ~full_path:filename dump_data.identifiers "Str"
    (fun ~loc -> Issue.v ~loc ())

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
