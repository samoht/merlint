(** E215: Use Fmt.failwith instead of failwith (Fmt.str ...) *)

module T = Ocaml_typing.Typedtree

let is_failwith expr = Query.Expr.callee_ends_with expr [ "failwith" ]

type state = { filename : string; issues : unit Issue.t list ref }

let visit_expr state (expr : T.expression) =
  let flag () =
    state.issues :=
      Issue.v ~loc:(Loc.of_typed ~filename:state.filename expr.T.exp_loc) ()
      :: !(state.issues)
  in
  let fn, args = Query.Expr.application expr in
  if is_failwith fn then (
    if List.exists (fun arg -> Query.Expr.calls arg [ "Fmt"; "str" ]) args then
      flag ())
  else if Query.Expr.callee_ends_with fn [ "Fmt"; "kstr" ] then
    match args with
    | continuation :: _ when is_failwith continuation -> flag ()
    | _ -> ()

let init ctx = { filename = Context.filename ctx; issues = ref [] }
let finish _ state = List.rev !(state.issues)

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
    ~pp
    (Rule.pass ~init ~expr:visit_expr ~finish ())
