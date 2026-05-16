(** E216: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) *)

let check (ctx : Context.file) =
  let filename = ctx.filename in
  match File_view.parsetree (Context.view ctx) with
  | None -> []
  | Some structure ->
      let issues = ref [] in
      Ast.iter_apply structure (fun expr fn args ->
          if
            Ast.lident_last_eq "invalid_arg" fn
            && List.exists
                 (fun (_, arg) -> Ast.is_apply_of [ "Fmt"; "str" ] arg)
                 args
          then
            issues :=
              Issue.v ~loc:(Ast.merlint_of_loc ~filename expr.pexp_loc) ()
              :: !issues);
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
