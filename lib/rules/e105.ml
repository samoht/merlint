(** Pattern-based detection for catch-all exception handlers *)

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

let check (ctx : Context.file) =
  let content = Context.content ctx in
  let filename = ctx.filename in

  Traverse.process_lines_with_location filename content
    (fun _line_idx line loc ->
      if Re.execp try_with_wildcard_pattern line then
        Some (Issue.catch_all_exception ~loc)
      else None)
