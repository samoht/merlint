(** E923: MDX skips must not disable OCaml documentation examples. *)

type payload = { file : string; line : int }

let mdx_skip_re = Re.compile Re.(seq [ str "$MDX"; rep1 space; str "skip" ])

let md_ocaml_fence_re =
  Re.compile
    Re.(
      seq
        [
          bol;
          rep (alt [ char ' '; char '\t' ]);
          str "```";
          rep (alt [ char ' '; char '\t' ]);
          alt [ str "ocaml"; str "ml" ];
          alt [ eol; char ' '; char '\t' ];
        ])

let has_mdx_skip line = Re.execp mdx_skip_re line
let is_ocaml_fence line = Re.execp md_ocaml_fence_re line
let lines content = String.split_on_char '\n' content |> Array.of_list

let next_non_blank lines i =
  let rec loop j =
    if j >= Array.length lines then None
    else if String.trim lines.(j) = "" then loop (j + 1)
    else Some j
  in
  loop i

let issue path line =
  let display =
    Loc.current_dir_relative (Context.fpath_of_path path) |> Fpath.to_string
  in
  let loc =
    Location.v ~file:display ~start_line:line ~start_col:0 ~end_line:line
      ~end_col:0
  in
  Issue.v ~loc { file = display; line }

let scan_markdown path content =
  let lines = lines content in
  let issues = ref [] in
  Array.iteri
    (fun i line ->
      if has_mdx_skip line then
        match next_non_blank lines (i + 1) with
        | Some j when is_ocaml_fence lines.(j) ->
            issues := issue path (i + 1) :: !issues
        | Some _ | None -> ())
    lines;
  List.rev !issues

let scan_mli path content =
  let lines = lines content in
  let issues = ref [] in
  Array.iteri
    (fun i line ->
      if has_mdx_skip line then issues := issue path (i + 1) :: !issues)
    lines;
  List.rev !issues

let scan_file ctx path =
  let path = Context.resolve ctx path in
  match
    try Some (Context.file_content ctx path)
    with Sys_error _ | File_view.Analysis_error _ -> None
  with
  | None -> []
  | Some content ->
      if Path.has_ext ".mli" path then scan_mli path content
      else scan_markdown path content

let doc_path path =
  let s = Fpath.to_string path in
  Filename.check_suffix s ".md"
  || Filename.check_suffix s ".mld"
  || Filename.check_suffix s ".mli"

let sources_in_scope ctx =
  let index = Context.index ctx in
  let acc = ref [] in
  let add path = if doc_path path then acc := path :: !acc in
  Project_index.doc_files index
  |> List.iter (fun (d : Project_index.doc_file) -> add d.path);
  Project_index.source_files index
  |> List.iter (fun path ->
      if Filename.check_suffix (Fpath.to_string path) ".mli" then add path);
  List.sort_uniq Fpath.compare !acc

let check ctx = sources_in_scope ctx |> List.concat_map (scan_file ctx)

let pp ppf { file; line } =
  Fmt.pf ppf
    "%s:%d: MDX skip disables an OCaml documentation example; make the snippet \
     compile instead"
    file line

let rule =
  Rule.v ~code:"E923" ~title:"Skipped OCaml documentation example"
    ~hint:
      "Do not use [$MDX skip] on OCaml or ML examples in README.md, .mld, or \
       .mli files. These snippets are user-facing copy/paste material. Fix the \
       setup, split hidden support code into earlier MDX blocks, or make the \
       example smaller, but keep it type-checked."
    ~category:Rule.Documentation ~examples:[] ~pp (Project check)
