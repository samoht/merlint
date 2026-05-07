(** E217: Use Fmt.kstr f instead of f (Fmt.str ...) *)

(** Outer applications already covered by a more specific rule with a dedicated
    [Fmt.X] helper. Skip them here so the user sees only the specialized hint,
    not also the generic [Fmt.kstr] one. *)
let handled_by_specialized_rule fn =
  Ast.lident_last_eq "failwith" fn
  || Ast.lident_last_eq "invalid_arg" fn
  ||
  let path = Longident.flatten fn in
  path = [ "Alcotest"; "fail" ] || path = [ "fail" ]

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let content = Context.content ctx in
  match Ast.parse_structure ~filename content with
  | None -> []
  | Some structure ->
      let issues = ref [] in
      Ast.iter_expressions structure (fun expr ->
          let is_fmt_str = Ast.is_apply_of [ "Fmt"; "str" ] in
          let flag () =
            issues :=
              Issue.v ~loc:(Ast.loc_to_merlint ~filename expr.pexp_loc) ()
              :: !issues
          in
          match expr.pexp_desc with
          | Pexp_apply
              ( { pexp_desc = Pexp_ident { txt = fn; _ }; _ },
                [ (Asttypes.Nolabel, arg) ] )
            when is_fmt_str arg && not (handled_by_specialized_rule fn) ->
              flag ()
          | Pexp_construct (_, Some arg) when is_fmt_str arg -> flag ()
          | _ -> ());
      List.rev !issues

let pp ppf () =
  Fmt.pf ppf
    "Use Fmt.kstr f instead of f (Fmt.str ...) - Fmt.kstr threads the \
     formatted string into the continuation in one step, no intermediate \
     [Fmt.str] needed"

let rule =
  Rule.v ~code:"E217" ~title:"Use Fmt.kstr f Instead of f (Fmt.str)"
    ~category:Style_modernization
    ~hint:
      "Use Fmt.kstr f instead of f (Fmt.str ...). Fmt.kstr is the \
       continuation-passing variant of Fmt.str: it formats and hands the \
       resulting string to its first argument. The [<fn> (Fmt.str ...)] \
       pattern is dominated by [Fmt.kstr <fn> ...] for any single-argument \
       function or constructor. Specialized cases ([failwith], [invalid_arg], \
       [Alcotest.fail], [fail]) have dedicated helpers — see E215, E216, E616."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let parse s =
  if s = "" then Error (Fmt.str "empty input")
  else Ok s|};
        };
        {
          is_good = true;
          code =
            {|let parse s =
  if s = "" then Fmt.kstr (fun e -> Error e) "empty input"
  else Ok s|};
        };
      ]
    ~pp (File check)
