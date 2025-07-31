(** E619: Use Fmt.failwith instead of failwith (Fmt.str *)

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let content = Lazy.force ctx.content in

  (* Use the dump function to find failwith (Fmt.str patterns *)
  Dump.check_function_call_pattern content "failwith" "Fmt.str"
    (fun (line, line_num, _is_qualified) ->
      let loc =
        Location.v ~file:filename ~start_line:line_num ~start_col:0
          ~end_line:line_num ~end_col:(String.length line)
      in
      Issue.v ~loc ())
    filename

let pp _ppf () =
  Fmt.pf _ppf
    "Use Fmt.failwith instead of failwith (Fmt.str ...) - Fmt.failwith \
     provides printf-style formatting directly"

let rule =
  Rule.v ~code:"E619" ~title:"Use Fmt.failwith Instead of failwith (Fmt.str)"
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
