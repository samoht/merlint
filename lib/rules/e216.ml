(** E216: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) *)

module T = Ocaml_typing.Typedtree

let is_invalid_arg expr =
  Query.Expr.callee_ends_with expr [ "invalid_arg" ]

let check (ctx : Context.file) =
  let issues = ref [] in
  let filename = ctx.filename in
  Query.iter_expressions (Context.view ctx) (fun expr ->
      let flag () =
        issues := Issue.v ~loc:(Loc.of_typed ~filename expr.T.exp_loc) () :: !issues
      in
      let fn, args = Query.Expr.application expr in
      if is_invalid_arg fn then (
        if List.exists (fun arg -> Query.Expr.calls arg [ "Fmt"; "str" ]) args
        then flag ())
      else if Query.Expr.callee_ends_with fn [ "Fmt"; "kstr" ] then
        match args with
        | continuation :: _ when is_invalid_arg continuation -> flag ()
        | _ -> ());
  List.rev !issues

let pp ppf () =
  Fmt.pf ppf
    "Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) - \
     Fmt.invalid_arg provides printf-style formatting directly"

let rule =
  Rule.v ~code:"E216"
    ~title:"Use Fmt.invalid_arg Instead of invalid_arg (Fmt.str)"
    ~category:Style_modernization
    ~hint:
      "Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...). \
       Fmt.invalid_arg provides printf-style formatting directly, making the \
       code more concise and readable."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let validate_port port =
  if port < 0 || port > 65535 then
    invalid_arg (Fmt.str "Invalid port: %d" port)
  else port|};
        };
        {
          is_good = true;
          code =
            {|let validate_port port =
  if port < 0 || port > 65535 then
    Fmt.invalid_arg "Invalid port: %d" port
  else port|};
        };
      ]
    ~pp (File check)
