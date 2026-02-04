(** E616: Use failf instead of fail (Fmt.str *)

type payload = { is_alcotest : bool }

let check (ctx : Context.file) =
  (* Only check test files (those starting with test_) *)
  let filename = ctx.filename in
  let basename = Filename.basename filename in
  if
    not
      (String.starts_with ~prefix:"test_" basename
      && String.ends_with ~suffix:".ml" basename)
  then []
  else
    let content = Lazy.force ctx.content in

    (* Use the new dump function to find fail (Fmt.str patterns *)
    Dump.check_function_call_pattern content "fail" "Fmt.str"
      (fun (line, line_num, is_qualified) ->
        let loc =
          Location.v ~file:filename ~start_line:line_num ~start_col:0
            ~end_line:line_num ~end_col:(String.length line)
        in
        Issue.v ~loc { is_alcotest = is_qualified })
      filename

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
  | Error e -> Alcotest.fail (Fmt.str "Parse error: %s" e)
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
  | Error e -> Alcotest.failf "Parse error: %s" e
  | Ok _ -> ()

let test_invalid () =
  if not (is_valid data) then
    failf "Invalid data: %a" pp_data data|};
        };
      ]
    ~pp (File check)
