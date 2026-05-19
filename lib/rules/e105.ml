open Examples
(** E105: Catch-all Exception Handler *)

module T = Ocaml_typing.Typedtree

let is_wildcard_case (case : T.value T.case) =
  match case.c_lhs.pat_desc with Tpat_any -> true | _ -> false

type state = { filename : string; issues : unit Issue.t list ref }

let visit_expr state (expr : T.expression) =
  match expr.exp_desc with
  | Texp_try (_, cases, _) ->
      List.iter
        (fun case ->
          if is_wildcard_case case then
            state.issues :=
              Issue.v
                ~loc:(Loc.of_typed ~filename:state.filename case.c_lhs.pat_loc)
                ()
              :: !(state.issues))
        cases
  | _ -> ()

let init ctx = { filename = ctx.Context.filename; issues = ref [] }
let finish _ state = List.rev !(state.issues)

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
    ~pp
    (Rule.pass ~init ~expr:visit_expr ~finish ())
