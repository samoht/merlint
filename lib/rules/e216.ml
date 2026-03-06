(** E216: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) *)

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let content = Lazy.force ctx.content in

  Merlin.Dump.check_function_call_pattern content "invalid_arg" "Fmt.str"
    (fun (line, line_num, _is_qualified) ->
      let loc =
        Location.v ~file:filename ~start_line:line_num ~start_col:0
          ~end_line:line_num ~end_col:(String.length line)
      in
      Issue.v ~loc ())
    filename

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
