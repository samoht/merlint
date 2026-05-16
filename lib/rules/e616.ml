(** E616: Use failf instead of fail (Fmt.str ...) *)

open Ocaml_parsing

type payload = { is_alcotest : bool }

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let basename = Filename.basename filename in
  if
    not (String.starts_with ~prefix:"test_" basename && File_kind.is_ml basename)
  then []
  else
    match File_view.parsetree (Context.view ctx) with
    | None -> []
    | Some structure ->
        let issues = ref [] in
        Ast.iter_apply structure (fun expr fn args ->
            let path = Longident.flatten fn in
            let is_alcotest_fail = path = [ "Alcotest"; "fail" ] in
            let is_bare_fail = path = [ "fail" ] in
            if
              (is_alcotest_fail || is_bare_fail)
              && List.exists
                   (fun (_, arg) -> Ast.is_apply_of [ "Fmt"; "str" ] arg)
                   args
            then
              issues :=
                Issue.v
                  ~loc:(Ast.merlint_of_loc ~filename expr.pexp_loc)
                  { is_alcotest = is_alcotest_fail }
                :: !issues);
        List.rev !issues

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
    ~pp (File check)
