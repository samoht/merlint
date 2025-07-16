(** Simple text-based detection for Error patterns *)

let check (ctx : Context.file) =
  let content = Context.content ctx in
  let filename = ctx.filename in

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

  (* Check each line using the traverse helper *)
  Traverse.process_lines_with_location filename content
    (fun _line_idx line location ->
      (* Don't flag error helper definitions themselves *)
      if
        Re.execp error_fmt_str_pattern line
        && not (Re.execp err_helper_pattern line)
      then
        Some
          (Issue.error_pattern ~loc:location
             ~error_message:"Error (Fmt.str ...)" ~suggested_function:"err_*")
      else None)
