(** Simple text-based detection for Error patterns *)

let check_error_patterns file_content =
  let issues = ref [] in

  (* Split content into lines for line number tracking *)
  let lines = String.split_on_char '\n' file_content in

  (* Pattern to match Error (Fmt.str ...) constructs *)
  let error_fmt_str_pattern =
    Re.compile
      (Re.seq
         [
           Re.str "Error";
           Re.rep Re.space;
           Re.str "(";
           Re.rep Re.space;
           Re.str "Fmt.str";
         ])
  in

  (* Pattern to match error helper function definitions *)
  let err_helper_pattern =
    Re.compile (Re.seq [ Re.str "let"; Re.rep1 Re.space; Re.str "err_" ])
  in

  (* Check each line *)
  List.iteri
    (fun line_idx line ->
      (* Don't flag error helper definitions themselves *)
      if
        Re.execp error_fmt_str_pattern line
        && not (Re.execp err_helper_pattern line)
      then
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
        issues :=
          Issue.Error_pattern
            {
              location;
              error_message = "Error (Fmt.str ...)";
              suggested_function = "err_*";
            }
          :: !issues)
    lines;

  List.rev !issues

let check file_path file_content =
  let issues = check_error_patterns file_content in
  (* Update locations with file path *)
  List.map
    (fun issue ->
      match issue with
      | Issue.Error_pattern ({ location; _ } as data) ->
          Issue.Error_pattern
            { data with location = { location with file = file_path } }
      | _ -> issue)
    issues
