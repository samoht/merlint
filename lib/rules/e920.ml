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
        (* .mli / .mld -- odoc-style {[ ... ]} blocks *)
        Re.execp odoc_block_re content

let mdx_covered_files ctx dune_path =
  match content ctx dune_path with
  | None -> []
  | Some content -> (
      match Dune.File.of_string content with
      | Ok file -> Dune.File.mdx_files file
      | Error _ -> [])

let dune_in dir = Filename.concat (Fpath.to_string dir) "dune"

let scan_dir ctx dir =
  let dune_path = dune_in dir in
  if not (Sys.file_exists dune_path) then []
  else
    let covered = mdx_covered_files ctx dune_path in
    let display_dune =
      Fpath.v dune_path |> Loc.relative_to_cwd |> Fpath.to_string
    in
    let dir_str = Fpath.to_string dir in
    let entries =
      try Sys.readdir dir_str |> Array.to_list with Sys_error _ -> []
    in
    List.filter_map
      (fun name ->
        let path = Filename.concat dir_str name in
        let is_doc =
          name = "README.md"
          || Filename.check_suffix name ".mli"
          || Filename.check_suffix name ".mld"
        in
        if (not is_doc) || List.mem name covered then None
        else if has_ocaml_code ctx path then
          let display_doc =
            Fpath.v path |> Loc.relative_to_cwd |> Fpath.to_string
          in
          Some
            (Issue.v ~loc:(Location.in_file display_doc)
               { dune_file = display_dune; doc_file = name })
        else None)
      entries

(* All directories known to contain a dune file: every package's source_dir
   (for the dune-project dune file) plus every library's source_dir. *)
let dune_dirs index =
  let dirs = ref [] in
  let add dir = dirs := dir :: !dirs in
  Project_index.source_packages_nodes index
  |> List.iter (fun pkg ->
      Option.iter add (Project_index.Package.source_dir pkg);
      Project_index.package_libraries pkg
      |> List.iter (fun lib ->
          Option.iter add (Project_index.Library.source_dir lib)));
  List.sort_uniq Fpath.compare !dirs

let check (ctx : Context.project) =
  Context.index ctx |> dune_dirs |> List.concat_map (scan_dir ctx)

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
