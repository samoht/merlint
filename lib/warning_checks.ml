(** Warning silence detection

    This module checks for code that silences warnings instead of fixing them.
*)

let warning_attr_regex =
  Re.compile
    (Re.seq
       [
         Re.str "[@";
         Re.rep Re.space;
         Re.opt (Re.seq [ Re.str "ocaml"; Re.str "." ]);
         Re.str "warning";
         Re.rep Re.space;
         Re.str "\"-";
         Re.group (Re.rep1 Re.digit);
         Re.str "\"";
       ])

let warning_attr2_regex =
  Re.compile
    (Re.seq
       [
         Re.str "[@@";
         Re.rep Re.space;
         Re.opt (Re.seq [ Re.str "ocaml"; Re.str "." ]);
         Re.str "warning";
         Re.rep Re.space;
         Re.str "\"-";
         Re.group (Re.rep1 Re.digit);
         Re.str "\"";
       ])

let warning_attr3_regex =
  Re.compile
    (Re.seq
       [
         Re.str "[@@@";
         Re.rep Re.space;
         Re.opt (Re.seq [ Re.str "ocaml"; Re.str "." ]);
         Re.str "warning";
         Re.rep Re.space;
         Re.str "\"-";
         Re.group (Re.rep1 Re.digit);
         Re.str "\"";
       ])

let check_line_for_warning filename line_num line =
  let issues = ref [] in
  (* Check for [@warning] *)
  (match Re.exec_opt warning_attr_regex line with
  | Some m ->
      let warning_num = Re.Group.get m 1 in
      issues :=
        Issue.Silenced_warning
          {
            location =
              Location.create ~file:filename ~start_line:line_num ~start_col:0
                ~end_line:line_num ~end_col:0;
            warning_number = warning_num;
          }
        :: !issues
  | None -> ());

  (* Check for [@@warning] *)
  (match Re.exec_opt warning_attr2_regex line with
  | Some m ->
      let warning_num = Re.Group.get m 1 in
      issues :=
        Issue.Silenced_warning
          {
            location =
              Location.create ~file:filename ~start_line:line_num ~start_col:0
                ~end_line:line_num ~end_col:0;
            warning_number = warning_num;
          }
        :: !issues
  | None -> ());

  (* Check for [@@@warning] *)
  (match Re.exec_opt warning_attr3_regex line with
  | Some m ->
      let warning_num = Re.Group.get m 1 in
      issues :=
        Issue.Silenced_warning
          {
            location =
              Location.create ~file:filename ~start_line:line_num ~start_col:0
                ~end_line:line_num ~end_col:0;
            warning_number = warning_num;
          }
        :: !issues
  | None -> ());

  !issues

(** Check if content contains silenced warnings *)
let check_silenced_warnings filename content =
  let lines = String.split_on_char '\n' content in
  let rec check_lines line_num acc = function
    | [] -> acc
    | line :: rest ->
        let line_issues = check_line_for_warning filename line_num line in
        check_lines (line_num + 1) (line_issues @ acc) rest
  in
  check_lines 1 [] lines

(** Check all files for silenced warnings *)
let check files =
  List.concat_map
    (fun filename ->
      if
        String.ends_with ~suffix:".ml" filename
        || String.ends_with ~suffix:".mli" filename
      then
        try
          let content =
            In_channel.with_open_text filename In_channel.input_all
          in
          check_silenced_warnings filename content
        with _ -> []
      else [])
    files
