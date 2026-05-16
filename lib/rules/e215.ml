(** E215: Use Fmt.failwith instead of failwith (Fmt.str ...) *)

let check (ctx : Context.file) =
  let filename = ctx.filename in
  match File_view.parsetree (Context.view ctx) with
  | None -> []
  | Some structure ->
      let issues = ref [] in
      Ast.iter_apply structure (fun expr fn args ->
          if
            Ast.lident_last_eq "failwith" fn
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
    "Use Fmt.failwith instead of failwith (Fmt.str ...) - Fmt.failwith \
     provides printf-style formatting directly"

let rule =
  Rule.v ~code:"E215" ~title:"Use Fmt.failwith Instead of failwith (Fmt.str)"
    ~category:Style_modernization
    ~hint:
      "Use Fmt.failwith instead of failwith (Fmt.str ...). Fmt.failwith \
       provides printf-style formatting directly, making the code more concise \
       and readable."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let validate_input input =
  if String.length input = 0 then
    failwith (Fmt.str "Empty input provided")
  else if String.length input > 100 then
    failwith (Fmt.str "Input too long: %d characters" (String.length input))
  else
    input|};
        };
        {
          is_good = true;
          code =
            {|let validate_input input =
  if String.length input = 0 then
    Fmt.failwith "Empty input provided"
  else if String.length input > 100 then
    Fmt.failwith "Input too long: %d characters" (String.length input)
  else
    input|};
        };
      ]
    ~pp (File check)
