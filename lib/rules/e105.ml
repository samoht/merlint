open Examples
(** E105: Catch-all Exception Handler *)

open Ocaml_parsing

let is_wildcard_case (case : Parsetree.case) =
  match case.pc_lhs.ppat_desc with Ppat_any -> true | _ -> false

let check (ctx : Context.file) =
  let filename = ctx.Context.filename in
  match File_view.parsetree (Context.view ctx) with
  | None -> []
  | Some structure ->
      let issues = ref [] in
      Ast.iter_expressions structure (fun (expr : Parsetree.expression) ->
          match expr.pexp_desc with
          | Pexp_try (_, cases) ->
              List.iter
                (fun (case : Parsetree.case) ->
                  if is_wildcard_case case then
                    issues :=
                      Issue.v
                        ~loc:(Ast.merlint_of_loc ~filename case.pc_lhs.ppat_loc)
                        ()
                      :: !issues)
                cases
          | _ -> ());
      List.rev !issues

let pp ppf () =
  Fmt.pf ppf
    "Catch-all exception handler found. This can hide unexpected errors."

let rule =
  Rule.v ~code:"E105" ~title:"Catch-all Exception Handler"
    ~category:Security_safety
    ~hint:
      "Catch-all exception handlers (with _ ->) can hide unexpected errors and \
       make debugging difficult. Always handle specific exceptions explicitly. \
       If you must catch all exceptions, log them or re-raise after cleanup."
    ~examples:
      [
        Example.bad E105.broad_ml;
        Example.good E105.specific_ml;
        Example.good E105.with_logging_ml;
      ]
    ~pp (File check)
