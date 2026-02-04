open Examples
(** E105: Catch-all Exception Handler *)

(** Payload for catch-all exception issues *)

(* Pattern to match try...with _ -> constructs *)
let try_with_wildcard_pattern =
  Re.compile
    (Re.seq
       [
         Re.str "with";
         Re.rep1 Re.space;
         Re.str "_";
         Re.rep Re.space;
         Re.str "->";
       ])

(* Check if a line is likely to be a comment *)
let is_comment_line line =
  let trimmed = String.trim line in
  String.starts_with ~prefix:"(*" trimmed
  || String.starts_with ~prefix:"*" trimmed

(* Check if the pattern is inside a string literal *)
let is_in_string line pattern_start =
  (* Count quotes before the pattern *)
  let rec count_quotes i count =
    if i >= pattern_start then count
    else if i + 1 < String.length line && line.[i] = '\\' && line.[i + 1] = '"'
    then count_quotes (i + 2) count (* Skip escaped quote *)
    else if line.[i] = '"' then count_quotes (i + 1) (count + 1)
    else count_quotes (i + 1) count
  in
  let quote_count = count_quotes 0 0 in
  quote_count mod 2 = 1 (* Odd number of quotes means we're inside a string *)

let check (ctx : Context.file) =
  let content = Context.content ctx in
  let filename = ctx.Context.filename in

  File.process_lines_with_location filename content (fun line_idx line loc ->
      ignore line_idx;
      if not (is_comment_line line) then
        match Re.exec_opt try_with_wildcard_pattern line with
        | Some m ->
            let start_pos = Re.Group.start m 0 in
            if not (is_in_string line start_pos) then Some (Issue.v ~loc ())
            else None
        | None -> None
      else None)

let pp ppf () =
  Fmt.pf ppf
    "Catch-all exception handler found. This can hide unexpected errors."

let rule =
  Rule.v ~code:"E105" ~title:"Catch-all Exception Handler"
    ~category:Security_safety
    ~hint:
      "Catch-all exception handlers (with _ ->) can hide unexpected errors and \
       make debugging difficult. Always handle specific exceptions explicitly. \
       If you must catch all exceptions, log them or re-raise after cleanup."
    ~examples:
      [
        Example.bad E105.broad_ml;
        Example.good E105.specific_ml;
        Example.good E105.with_logging_ml;
      ]
    ~pp (File check)
