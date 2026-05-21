(** E920: documentation files with OCaml code blocks must be MDX-tested. *)

type payload = { dune_file : string; doc_file : string }

(* Markdown fenced ``` ocaml block, allowing language tags like ocaml,
   ocaml env=foo, ocaml skip, etc. *)
let md_ocaml_re =
  Re.compile
    Re.(
      seq
        [
          bol;
          str "```";
          rep (alt [ char ' '; char '\t' ]);
          str "ocaml";
          alt [ char '\n'; char ' '; char '\t' ];
        ])

(* Odoc verbatim/code block: {[ ... ]}. Language defaults to OCaml. *)
let odoc_block_re = Re.compile (Re.str "{[")

let content ctx path =
  try Some (Context.file_content ctx path)
  with Sys_error _ | File_view.Analysis_error _ -> None

let has_ocaml_code ctx path =
  match content ctx path with
  | None -> false
  | Some content ->
      if Context.Path.has_ext ".md" path then Re.execp md_ocaml_re content
      else Re.execp odoc_block_re content

let issue_for ctx (doc : Project_index.doc_file) =
  if doc.mdx then None
  else
    let path = Context.resolve ctx doc.path in
    if not (has_ocaml_code ctx path) then None
    else
      let display = Loc.current_dir_relative doc.path |> Fpath.to_string in
      let dune_file =
        Loc.current_dir_relative doc.Project_index.dune_file |> Fpath.to_string
      in
      Some
        (Issue.v ~loc:(Location.in_file display)
           { dune_file; doc_file = display })

let docs_in_scope ctx =
  let docs = ref [] in
  Context.index ctx |> Project_index.source_package_list
  |> List.iter (fun pkg ->
      List.iter
        (fun d -> docs := d :: !docs)
        (Project_index.Package.doc_files pkg);
      Project_index.package_libraries pkg
      |> List.iter (fun lib ->
          List.iter
            (fun d -> docs := d :: !docs)
            (Project_index.Library.doc_files lib)));
  List.sort_uniq
    (fun a b -> Fpath.compare a.Project_index.path b.Project_index.path)
    !docs

let check (ctx : Context.project) =
  docs_in_scope ctx |> List.filter_map (issue_for ctx)

let pp ppf { dune_file; doc_file } =
  Fmt.pf ppf "%s: contains OCaml code blocks but %s has no (mdx ...) stanza"
    doc_file dune_file

let rule =
  Rule.v ~code:"E920" ~title:"Untested OCaml code in documentation"
    ~hint:
      "When a README.md, .mli or .mld contains OCaml code examples, add an \
       (mdx (files <file>)) stanza to the owning dune file so the snippets are \
       type-checked and run during dune test."
    ~category:Rule.Documentation ~examples:[] ~pp (Project check)
