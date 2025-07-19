(** E410: Bad Documentation Style *)

type payload = { value_name : string; location : Location.t; issue : string }

let check_doc_style doc =
  let issues = ref [] in

  (* Check if it starts with a capital letter *)
  (if String.length doc > 0 then
     let first_char = String.get doc 0 in
     if first_char <> '[' && not (Char.uppercase_ascii first_char = first_char)
     then issues := "should start with a capital letter or '['" :: !issues);

  (* Check if it ends with a period *)
  let trimmed = String.trim doc in
  if
    String.length trimmed > 0
    && not
         (String.ends_with ~suffix:"." trimmed
         || String.ends_with ~suffix:"*)" trimmed)
  then issues := "should end with a period" :: !issues;

  (* Check for redundant "This function..." phrases *)
  let lower = String.lowercase_ascii doc in
  if
    String.starts_with ~prefix:"this function" lower
    || String.starts_with ~prefix:"this method" lower
    || String.starts_with ~prefix:"this module" lower
    || String.starts_with ~prefix:"this type" lower
  then issues := "avoid redundant phrases like 'This function...'" :: !issues;

  !issues

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
                        String.sub l 3 (String.length l - 5) |> String.trim
                      else String.sub l 0 (String.length l - 2) |> String.trim
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
            let value_name =
              let val_line = String.trim line in
              try
                let start = String.index val_line ' ' + 1 in
                let end_idx =
                  try String.index_from val_line start ' '
                  with Not_found -> String.index val_line ':'
                in
                String.sub val_line start (end_idx - start)
              with _ -> "unknown"
            in
            scan (idx + 1) ((value_name, doc, doc_line + 1, idx + 1) :: acc)
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
      (fun (value_name, doc, doc_line, _val_line) ->
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
          (* Check doc comment style *)
          let style_issues = check_doc_style doc in
          match style_issues with
          | [] -> None
          | issues ->
              let loc =
                Location.create ~file:ctx.filename ~start_line:doc_line
                  ~start_col:0 ~end_line:doc_line ~end_col:0
              in
              let issue_text = String.concat ", " issues in
              Some
                (Issue.v ~loc
                   { value_name; location = loc; issue = issue_text }))
      doc_comments

let pp ppf { value_name; location = _; issue } =
  Fmt.pf ppf "Documentation for '%s' %s" value_name issue

let rule =
  Rule.v ~code:"E410" ~title:"Bad Documentation Style" ~category:Documentation
    ~hint:
      "Documentation should follow OCaml conventions: start with a capital \
       letter, end with a period, and use proper grammar. Avoid redundant \
       phrases like 'This function...' - just state what it does directly."
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
