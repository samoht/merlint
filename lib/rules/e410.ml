(** E410: Bad Documentation Style *)

type payload = { value_name : string; location : Location.t; issue : string }

let is_function_signature signature =
  (* Check if the signature contains -> indicating a function *)
  Re.execp (Re.compile (Re.str "->")) signature

let extract_doc_comments content =
  let lines = String.split_on_char '\n' content in
  let rec scan idx acc =
    if idx >= List.length lines then List.rev acc
    else
      let line = List.nth lines idx in
      if String.starts_with ~prefix:"val " (String.trim line) then
        (* Found a value declaration, check for doc comment before it *)
        let rec find_doc i =
          if i < 0 then None
          else
            let prev_line = String.trim (List.nth lines i) in
            if prev_line = "" then find_doc (i - 1)
            else if String.starts_with ~prefix:"(**" prev_line then
              (* Found doc comment, extract it *)
              let rec extract_multiline j acc =
                if j >= List.length lines then
                  (String.concat " " (List.rev acc), j)
                else
                  let l = String.trim (List.nth lines j) in
                  if String.ends_with ~suffix:"*)" l then
                    let cleaned =
                      if j = i then
                        (* Single line: (** text *) *)
                        String.sub l 3 (String.length l - 5) |> String.trim
                      else
                        (* Last line of multi-line, keep content as-is *)
                        let content =
                          String.sub l 0 (String.length l - 2) |> String.trim
                        in
                        content
                    in
                    (String.concat " " (List.rev (cleaned :: acc)), j + 1)
                  else if j = i then
                    let cleaned =
                      String.sub l 3 (String.length l) |> String.trim
                    in
                    extract_multiline (j + 1) (cleaned :: acc)
                  else extract_multiline (j + 1) (l :: acc)
              in
              let doc_text, _ = extract_multiline i [] in
              Some (doc_text, i)
            else if
              String.starts_with ~prefix:"(*" prev_line
              && not (String.starts_with ~prefix:"(**" prev_line)
            then
              (* Regular comment, not doc comment - this is bad *)
              Some ("BAD_COMMENT", i)
            else None
        in
        match find_doc (idx - 1) with
        | Some (doc, doc_line) ->
            let val_line = String.trim line in
            let value_name, signature =
              try
                let start = String.index val_line ' ' + 1 in
                let colon_idx = String.index val_line ':' in
                let name_end =
                  try String.index_from val_line start ' '
                  with Not_found -> colon_idx
                in
                let name =
                  String.sub val_line start (min name_end colon_idx - start)
                in
                let sig_start = colon_idx + 1 in
                let signature =
                  String.sub val_line sig_start
                    (String.length val_line - sig_start)
                  |> String.trim
                in
                (name, signature)
              with _ -> ("unknown", "")
            in
            scan (idx + 1)
              ((value_name, signature, doc, doc_line + 1, idx + 1) :: acc)
        | None -> scan (idx + 1) acc
      else scan (idx + 1) acc
  in
  scan 0 []

let check (ctx : Context.file) =
  (* Only check .mli files *)
  if not (String.ends_with ~suffix:".mli" ctx.filename) then []
  else
    let content = Lazy.force ctx.content in
    let doc_comments = extract_doc_comments content in

    List.filter_map
      (fun (value_name, signature, doc, doc_line, _val_line) ->
        if doc = "BAD_COMMENT" then
          (* Using regular comment instead of doc comment *)
          let loc =
            Location.create ~file:ctx.filename ~start_line:doc_line ~start_col:0
              ~end_line:doc_line ~end_col:0
          in
          Some
            (Issue.v ~loc
               {
                 value_name;
                 location = loc;
                 issue =
                   "use doc comment (** ... *) instead of regular comment (* \
                    ... *)";
               })
        else
          (* Check doc comment style using the docs module *)
          let style_issues =
            if is_function_signature signature then
              Docs.check_function_doc ~name:value_name ~doc
            else Docs.check_value_doc ~name:value_name ~doc
          in
          match style_issues with
          | [] -> None
          | issues ->
              let loc =
                Location.create ~file:ctx.filename ~start_line:doc_line
                  ~start_col:0 ~end_line:doc_line ~end_col:0
              in
              let issue_texts =
                List.map (Format.asprintf "%a" Docs.pp_style_issue) issues
              in
              let issue_text = String.concat ", " issue_texts in
              Some
                (Issue.v ~loc
                   { value_name; location = loc; issue = issue_text }))
      doc_comments

let pp ppf { value_name; location = _; issue } =
  Fmt.pf ppf "Documentation for '%s' %s" value_name issue

let rule =
  Rule.v ~code:"E410" ~title:"Bad Documentation Style" ~category:Documentation
    ~hint:
      "Follow OCaml documentation conventions: Functions should use '[name \
       args] description.' format. All documentation should end with a period. \
       Avoid redundant phrases like 'This function...'."
    ~examples:
      [
        {
          is_good = true;
          code =
            {|val is_bot : t -> bool
(** [is_bot u] is [true] if [u] is a bot user. *)|};
        };
        {
          is_good = true;
          code = {|type id = string
(** A user identifier. *)|};
        };
      ]
    ~pp (File check)
