(** E215: Use Fmt.failwith instead of failwith (Fmt.str ...) *)

let check (ctx : Context.file) =
  let issues = ref [] in
  File_view.iter_applications (Context.view ctx) (fun call ->
      let callee = File_view.Call.callee call in
      if
        File_view.Name.base callee = "failwith"
        && List.exists
             (fun arg -> File_view.Call.Arg.is_call arg ~path:[ "Fmt"; "str" ])
             (File_view.Call.args call)
      then issues := Issue.v ~loc:(File_view.Call.loc call) () :: !issues);
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
