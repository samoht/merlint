(** E410: Bad Documentation Style *)

type payload = { value_name : string; location : Location.t; issue : string }

let doc_signature typ =
  let rec labels acc typ =
    match File_view.Type_view.arrow typ with
    | Some (label, _arg, rest) -> labels (label :: acc) rest
    | None -> List.rev acc
  in
  let arg = function
    | Ocaml_parsing.Asttypes.Optional _ -> "?arg"
    | Labelled _ | Nolabel -> "arg"
  in
  labels [] typ |> List.map arg |> fun args ->
  String.concat " -> " (args @ [ "ret" ])

let style_issues item doc =
  let name = File_view.Item.name item in
  match File_view.Item.type_sig item with
  | Some typ when File_view.Type_view.is_function typ ->
      Docs.check_function_doc ~name ~signature:(doc_signature typ) ~doc
  | _ -> Docs.check_value_doc ~name ~doc

let doc_style_issue item doc =
  match style_issues item (File_view.Doc.text doc) with
  | [] -> None
  | issues ->
      let loc = File_view.Doc.loc doc in
      let issue =
        issues |> List.map Docs.style_issue_message |> String.concat ", "
      in
      Some
        (Issue.v ~loc
           { value_name = File_view.Item.name item; location = loc; issue })

let check_doc item =
  match File_view.Item.doc item with
  | Some doc -> doc_style_issue item doc
  | None -> None

(* Doc comments live in the artefact the compiler wrote; a typedtree
     typechecked from source carries none, so every declaration would look
     undocumented. Skip the file rather than report an absence nobody can see;
     the engine reports it as not fully examined. *)
let check (ctx : Context.file) =
  if not (File_kind.is_mli (Context.filename ctx)) then []
  else Context.view ctx |> File_view.value_items |> List.filter_map check_doc

let pp ppf { value_name; location = _; issue } =
  Fmt.pf ppf "Documentation for '%s' %s" value_name issue

let rule =
  Rule.v ~code:"E410" ~title:"Bad Documentation Style" ~category:Documentation
    ~hint:
      "Follow OCaml documentation conventions: when documentation starts with \
       [name ...], [name] should be the function or value being documented. \
       Operators should use infix notation like '[x op y] description.' All \
       documentation should end with a period. Avoid redundant phrases like \
       'This function...'."
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
        {
          is_good = true;
          code =
            {|val default : t
(** [default] is the default configuration. *)|};
        };
        {
          is_good = false;
          code = {|val default : t
(** The default configuration. *)|};
        };
      ]
    ~pp (File check)
