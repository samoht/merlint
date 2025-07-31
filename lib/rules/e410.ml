(** E410: Bad Documentation Style *)

type payload = { value_name : string; location : Location.t; issue : string }

let check (ctx : Context.file) =
  (* Only check .mli files *)
  if not (String.ends_with ~suffix:".mli" ctx.filename) then []
  else
    let content = Lazy.force ctx.content in
    let doc_comments = Docs.extract_doc_comments content in

    List.filter_map
      (fun Docs.{ value_name; signature; doc; doc_line; val_line = _ } ->
        if doc = "BAD_COMMENT" then
          (* Using regular comment instead of doc comment *)
          let loc =
            Location.v ~file:ctx.filename ~start_line:doc_line ~start_col:0
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
            if Docs.is_function_signature signature then
              Docs.check_function_doc ~name:value_name ~doc
            else Docs.check_value_doc ~name:value_name ~doc
          in
          match style_issues with
          | [] -> None
          | issues ->
              let loc =
                Location.v ~file:ctx.filename ~start_line:doc_line ~start_col:0
                  ~end_line:doc_line ~end_col:0
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
       args] description.' format. Operators should use infix notation like \
       '[x op y] description.' All documentation should end with a period. \
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
