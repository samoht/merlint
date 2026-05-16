(** E100: No Obj.magic *)

module Parsetree = Ocaml_parsing.Parsetree
module Ast_iterator = Ocaml_parsing.Ast_iterator
module Longident = Ocaml_parsing.Longident

let is_obj_magic lid =
  match Longident.flatten lid with
  | [ "Obj"; "magic" ] | [ "Stdlib"; "Obj"; "magic" ] -> true
  | _ -> false

let check ctx =
  match File_view.parsetree (Context.view ctx) with
  | None -> []
  | Some structure ->
      let issues = ref [] in
      let iterator =
        {
          Ast_iterator.default_iterator with
          expr =
            (fun self expr ->
              (match expr.Parsetree.pexp_desc with
              | Pexp_ident { txt; _ } when is_obj_magic txt ->
                  let loc =
                    Ast.merlint_of_loc ~filename:ctx.filename expr.pexp_loc
                  in
                  issues := Issue.v ~loc () :: !issues
              | _ -> ());
              Ast_iterator.default_iterator.expr self expr);
        }
      in
      iterator.structure iterator structure;
      List.rev !issues

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
