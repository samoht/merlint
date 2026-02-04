(** E340: Error Pattern Detection *)

type payload = { error_message : string; suggested_function : string }
(** Payload for error pattern issues *)

let check ctx =
  let content = Context.content ctx in
  let filename = ctx.filename in
  let outline = Context.outline ctx in

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

  (* Pattern to match Error (`Msg (Fmt.str ...)) constructs *)
  let error_msg_fmt_str_pattern =
    Re.compile
      (Re.seq
         [
           Re.str "Error";
           Re.rep Re.space;
           Re.str "(";
           Re.rep Re.space;
           Re.str "`Msg";
           Re.rep Re.space;
           Re.str "(";
           Re.rep Re.space;
           Re.str "Fmt.str";
         ])
  in

  (* Get all error helper functions from the outline *)
  let error_helpers =
    Outline.values outline
    |> List.filter_map (fun (item : Outline.item) ->
           if String.starts_with ~prefix:"err_" item.name then
             match item.range with
             | Some range -> Some (item.name, range)
             | None -> None
           else None)
  in

  (* Check if a line number is inside any error helper function *)
  let is_inside_error_helper line_num =
    List.exists
      (fun (_name, (range : Outline.range)) ->
        line_num >= range.start.line && line_num <= range.end_.line)
      error_helpers
  in

  (* Check each line using the traverse helper *)
  File.process_lines_with_location filename content
    (fun line_idx line location ->
      ignore line_idx;
      let line_num = location.Location.start_line in

      (* Only flag if we're not inside an error helper *)
      if not (is_inside_error_helper line_num) then
        if Re.execp error_fmt_str_pattern line then
          Some
            (Issue.v ~loc:location
               {
                 error_message = "Error (Fmt.str ...)";
                 suggested_function = "err_*";
               })
        else if Re.execp error_msg_fmt_str_pattern line then
          Some
            (Issue.v ~loc:location
               {
                 error_message = "Error (`Msg (Fmt.str ...))";
                 suggested_function = "err_*";
               })
        else None
      else None)

let pp ppf { error_message; suggested_function } =
  Fmt.pf ppf
    "Found '%s' pattern - consider using '%s' helper functions for consistent \
     error handling"
    error_message suggested_function

let rule =
  Rule.v ~code:"E340" ~title:"Error Pattern Detection"
    ~category:Style_modernization
    ~hint:
      "Using raw Error constructors with Fmt.str (including polymorphic \
       variants like `Msg) can lead to inconsistent error messages. Consider \
       creating error helper functions (prefixed with 'err_') that encapsulate \
       common error patterns and provide consistent formatting. Place these \
       error helpers at the top of the file to make it easier to see all the \
       different error cases in one place."
    ~examples:
      [ Example.bad Examples.E340.bad_ml; Example.good Examples.E340.good_ml ]
    ~pp (File check)
