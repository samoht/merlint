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
      if Filename.check_suffix path ".md" then Re.execp md_ocaml_re content
      else
        (* .mli / .mld — odoc-style {[ ... ]} blocks *)
        Re.execp odoc_block_re content

let mdx_covered_files ctx path =
  match content ctx path with
  | None -> []
  | Some content -> (
      match Dune.File.of_string content with
      | Ok file -> Dune.File.mdx_files file
      | Error _ -> [])

let scan_dir ctx dune_path =
  let dir = Filename.dirname dune_path in
  let covered = mdx_covered_files ctx dune_path in
  let entries = try Sys.readdir dir |> Array.to_list with Sys_error _ -> [] in
  List.filter_map
    (fun name ->
      let path = Filename.concat dir name in
      let is_doc =
        name = "README.md"
        || Filename.check_suffix name ".mli"
        || Filename.check_suffix name ".mld"
      in
      if (not is_doc) || List.mem name covered then None
      else if has_ocaml_code ctx path then
        Some
          (Issue.v ~loc:(Location.in_file path)
             { dune_file = dune_path; doc_file = name })
      else None)
    entries

let rec dune_files dir =
  let entries = try Sys.readdir dir |> Array.to_list with Sys_error _ -> [] in
  List.concat_map
    (fun entry ->
      let path = Filename.concat dir entry in
      let is_dir = try Sys.is_directory path with Sys_error _ -> false in
      if entry = "dune" && not is_dir then [ path ]
      else if
        is_dir
        && not (Dune_describe.skippable_subdir ~parent_dir:(Fpath.v dir) entry)
      then dune_files path
      else [])
    entries

let check (ctx : Context.project) =
  List.concat_map (scan_dir ctx) (dune_files ctx.project_root)

let pp ppf { dune_file; doc_file } =
  Fmt.pf ppf "%s/%s: contains OCaml code blocks but %s has no (mdx ...) stanza"
    (Filename.dirname dune_file)
    doc_file dune_file

let rule =
  Rule.v ~code:"E920" ~title:"Untested OCaml code in documentation"
    ~hint:
      "When a README.md, .mli or .mld contains OCaml code blocks (```ocaml \
       fenced or {[ ... ]} odoc), add an (mdx (files <file>)) stanza to the \
       same directory's dune file so the snippets are type-checked and run \
       during dune test."
    ~category:Rule.Documentation ~examples:[] ~pp (Project check)
