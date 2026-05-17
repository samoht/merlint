(** E216: Use Fmt.invalid_arg instead of invalid_arg (Fmt.str ...) *)

let check (ctx : Context.file) =
  let issues = ref [] in
  File_view.iter_applications (Context.view ctx) (fun call ->
      let callee = File_view.Call.callee call in
      if
        File_view.Name.base callee = "invalid_arg"
        && List.exists
             (fun arg -> File_view.Call.Arg.is_call arg ~path:[ "Fmt"; "str" ])
             (File_view.Call.args call)
      then issues := Issue.v ~loc:(File_view.Call.loc call) () :: !issues);
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
