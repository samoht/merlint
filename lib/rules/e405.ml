open Examples
(** E405: Missing Value Documentation *)

type payload = { value_name : string; location : Location.t }

let has_doc_comment content line_num =
  (* Check if there's a doc comment (** ... *) immediately before the given line *)
  let lines = String.split_on_char '\n' content in
  let rec check_backwards idx =
    if idx < 0 then false
    else
      let line = String.trim (List.nth lines idx) in
      if line = "" then
        (* Empty line, keep looking *)
        check_backwards (idx - 1)
      else if String.ends_with ~suffix:"*)" line then
        (* Found end of a comment, check if it's a doc comment *)
        (* Look for the start of this comment *)
        let rec find_comment_start i =
          if i < 0 then false
          else
            let l = String.trim (List.nth lines i) in
            if String.starts_with ~prefix:"(**" l then true
            else if String.starts_with ~prefix:"(*" l then false
            else find_comment_start (i - 1)
        in
        find_comment_start idx
      else if String.starts_with ~prefix:"(**" line then
        (* Single-line doc comment *)
        true
      else
        (* Any other content (including declarations), no doc comment immediately before *)
        false
  in
  check_backwards (line_num - 2)
(* -2 because line numbers are 1-based and we want to check the line before *)

let has_doc_comment_after content line_num =
  (* Check if there's a doc comment (** ... *) immediately after the given line *)
  let lines = String.split_on_char '\n' content in
  (* Convert 1-based line number to 0-based index for the line after *)
  let next_idx = line_num in
  if next_idx >= List.length lines then false
  else
    let line = String.trim (List.nth lines next_idx) in
    String.starts_with ~prefix:"(**" line

let check (ctx : Context.file) =
  (* Only check .mli files *)
  if not (String.ends_with ~suffix:".mli" ctx.filename) then []
  else
    let content = Lazy.force ctx.content in
    let outline = Context.outline ctx in

    (* Check all public values in the outline *)
    List.filter_map
      (fun item ->
        match item.Outline.kind with
        | Outline.Value -> (
            match item.range with
            | Some range ->
                let has_doc_before = has_doc_comment content range.start.line in
                let has_doc_after =
                  has_doc_comment_after content range.end_.line
                in
                if (not has_doc_before) && not has_doc_after then
                  let loc =
                    Location.v ~file:ctx.filename ~start_line:range.start.line
                      ~start_col:range.start.col ~end_line:range.end_.line
                      ~end_col:range.end_.col
                  in
                  Some (Issue.v ~loc { value_name = item.name; location = loc })
                else None
            | None -> None)
        | _ -> None)
      (Outline.values outline)

let pp ppf { value_name; location = _ } =
  Fmt.pf ppf "Public value '%s' is missing documentation" value_name

let rule =
  Rule.v ~code:"E405" ~title:"Missing Value Documentation"
    ~category:Documentation
    ~hint:
      "All public values should have documentation explaining their purpose \
       and usage. Add doc comments (** ... *) before or after value \
       declarations in .mli files."
    ~examples:[ Example.bad E405.bad_mli; Example.good E405.good_mli ]
    ~pp (File check)
