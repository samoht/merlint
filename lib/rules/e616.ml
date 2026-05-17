(** E616: Use failf instead of fail (Fmt.str ...) *)

type payload = { is_alcotest : bool }

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let basename = Filename.basename filename in
  if
    not (String.starts_with ~prefix:"test_" basename && File_kind.is_ml basename)
  then []
  else
    let issues = ref [] in
    File_view.iter_applications (Context.view ctx) (fun call ->
        let callee = File_view.Call.callee call in
        let is_alcotest_fail =
          File_view.Name.equals_path callee [ "Alcotest"; "fail" ]
        in
        let is_bare_fail = File_view.Name.base callee = "fail" in
        if
          (is_alcotest_fail || is_bare_fail)
          && List.exists
               (fun arg ->
                 File_view.Call.Arg.is_call arg ~path:[ "Fmt"; "str" ])
               (File_view.Call.args call)
        then
          issues :=
            Issue.v ~loc:(File_view.Call.loc call)
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
