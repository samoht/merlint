open Examples
(** E405: Missing Value Documentation *)

type payload = { value_name : string; location : Location.t }

let has_doc_comment content line_num =
  (* Check if there's a doc comment (** ... *) before the given line *)
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
        (* Some other content, no doc comment *)
        false
  in
  check_backwards (line_num - 2)
(* -2 because line numbers are 1-based and we want to check the line before *)

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
                let has_doc = has_doc_comment content range.start.line in
                if not has_doc then
                  let loc =
                    Location.create ~file:ctx.filename
                      ~start_line:range.start.line ~start_col:range.start.col
                      ~end_line:range.end_.line ~end_col:range.end_.col
                  in
                  Some (Issue.v ~loc { value_name = item.name; location = loc })
                else None
            | None -> None)
        | _ -> None)
      (Outline.get_values outline)

let pp ppf { value_name; location = _ } =
  Fmt.pf ppf "Public value '%s' is missing documentation" value_name

let rule =
  Rule.v ~code:"E405" ~title:"Missing Value Documentation"
    ~category:Documentation
    ~hint:
      "All public values should have documentation explaining their purpose \
       and usage. Add doc comments (** ... *) above value declarations in .mli \
       files."
    ~examples:[ Example.bad E405.bad_mli; Example.good E405.good_mli ]
    ~pp (File check)
