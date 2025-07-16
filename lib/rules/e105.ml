(** Pattern-based detection for catch-all exception handlers *)

let check_catch_all_exceptions file_content =
  let issues = ref [] in

  (* Split content into lines for line number tracking *)
  let lines = String.split_on_char '\n' file_content in

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
  in

  (* Check each line *)
  List.iteri
    (fun line_idx line ->
      if Re.execp try_with_wildcard_pattern line then
        let location =
          {
            Location.file = "";
            (* Will be filled by caller *)
            start_line = line_idx + 1;
            start_col = 0;
            (* We don't have precise column info with this approach *)
            end_line = line_idx + 1;
            end_col = 0;
          }
        in
        issues := Issue.Catch_all_exception { location } :: !issues)
    lines;

  List.rev !issues

let check (ctx : Context.file) =
  let content = Context.content ctx in
  let filename = ctx.filename in
  let issues = check_catch_all_exceptions content in
  (* Update location with filename *)
  List.map
    (fun issue ->
      match issue with
      | Issue.Catch_all_exception data ->
          Issue.Catch_all_exception
            { location = { data.location with file = filename } }
      | _ -> issue)
    issues
