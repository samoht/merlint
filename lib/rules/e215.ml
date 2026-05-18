(** E215: Use Fmt.failwith instead of failwith (Fmt.str ...) *)

module T = Ocaml_typing.Typedtree

let is_failwith expr =
  Query.Expr.callee_ends_with expr [ "failwith" ]

let check (ctx : Context.file) =
  let issues = ref [] in
  let filename = ctx.filename in
  Query.iter_expressions (Context.view ctx) (fun expr ->
      let flag () =
        issues := Issue.v ~loc:(Loc.of_typed ~filename expr.T.exp_loc) () :: !issues
      in
      let fn, args = Query.Expr.application expr in
      if is_failwith fn then (
        if List.exists (fun arg -> Query.Expr.calls arg [ "Fmt"; "str" ]) args
        then flag ())
      else if Query.Expr.callee_ends_with fn [ "Fmt"; "kstr" ] then
        match args with
        | continuation :: _ when is_failwith continuation -> flag ()
        | _ -> ());
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
