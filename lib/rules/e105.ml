open Examples
(** E105: Catch-all Exception Handler *)

module T = Ocaml_typing.Typedtree

let is_wildcard_case (case : T.value T.case) =
  match case.c_lhs.pat_desc with Tpat_any -> true | _ -> false

let check (ctx : Context.file) =
  let filename = ctx.Context.filename in
  let issues = ref [] in
  Query.iter_expressions (Context.view ctx) (fun (expr : T.expression) ->
      match expr.exp_desc with
      | Texp_try (_, cases, _) ->
          List.iter
            (fun case ->
              if is_wildcard_case case then
                issues :=
                  Issue.v ~loc:(Loc.of_typed ~filename case.c_lhs.pat_loc) ()
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
