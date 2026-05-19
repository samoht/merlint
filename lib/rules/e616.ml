(** E616: Use failf instead of fail (Fmt.str ...) *)

type payload = { is_alcotest : bool }

module T = Ocaml_typing.Typedtree

let path_ends_with path suffix =
  let rec drop n xs =
    if n <= 0 then xs else match xs with [] -> [] | _ :: xs -> drop (n - 1) xs
  in
  let len = List.length path in
  let suffix_len = List.length suffix in
  len >= suffix_len && drop (len - suffix_len) path = suffix

let is_fail_path path =
  path_ends_with path [ "Alcotest"; "fail" ]
  || path_ends_with path [ "Alcobar"; "fail" ]

let is_fail_expr expr =
  match Query.Expr.callee_parts expr with
  | Some path -> is_fail_path path
  | None -> false

let is_test_or_fuzz_file filename =
  let basename = Filename.basename filename in
  File_kind.is_ml basename
  && (String.starts_with ~prefix:"test_" basename
     || String.starts_with ~prefix:"fuzz_" basename)

type state = {
  filename : string;
  enabled : bool;
  issues : payload Issue.t list ref;
}

let add state expr is_alcotest =
  state.issues :=
    Issue.v
      ~loc:(Loc.of_typed ~filename:state.filename expr.T.exp_loc)
      { is_alcotest }
    :: !(state.issues)

let visit_expr state (expr : T.expression) =
  if state.enabled then
    match expr.exp_desc with
    | Texp_apply (fn, args) when is_fail_expr fn ->
        if
          List.exists
            (fun arg -> Query.Expr.calls arg [ "Fmt"; "str" ])
            (Query.Expr.positional_args args)
        then add state expr true
    | Texp_apply (fn, args)
      when Query.Expr.callee_ends_with fn [ "Fmt"; "kstr" ] -> (
        match Query.Expr.positional_args args with
        | continuation :: _ when is_fail_expr continuation ->
            add state expr true
        | _ -> ())
    | _ -> ()

let select ctx = is_test_or_fuzz_file ctx.Context.filename

let init ctx =
  let filename = ctx.Context.filename in
  { filename; enabled = true; issues = ref [] }

let finish _ state = List.rev !(state.issues)

let pp ppf { is_alcotest } =
  if is_alcotest then
    Fmt.pf ppf
      "Use Alcotest.failf instead of Alcotest.fail (Fmt.str ...) - failf \
       provides printf-style formatting directly"
  else
    Fmt.pf ppf
      "Use failf instead of fail (Fmt.str ...) - failf provides printf-style \
       formatting directly"

let rule =
  Rule.v ~code:"E616" ~title:"Use failf Instead of fail (Fmt.str)"
    ~category:Testing
    ~hint:
      "In test files, use Alcotest.failf or failf instead of Alcotest.fail \
       (Fmt.str ...) or fail (Fmt.str ...). The failf function provides \
       printf-style formatting directly, making the code more concise and \
       readable."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let test_parse () =
  match parse input with
  | Error e -> Alcotest.fail (Fmt.str "Parse error: %s" (Json.Error.to_string e))
  | Ok _ -> ()

let test_invalid () =
  if not (is_valid data) then
    fail (Fmt.str "Invalid data: %a" pp_data data)|};
        };
        {
          is_good = true;
          code =
            {|let test_parse () =
  match parse input with
  | Error e -> Alcotest.failf "Parse error: %s" (Json.Error.to_string e)
  | Ok _ -> ()

let test_invalid () =
  if not (is_valid data) then
    failf "Invalid data: %a" pp_data data|};
        };
      ]
    ~pp
    (Rule.pass ~select ~init ~expr:visit_expr ~finish ())
