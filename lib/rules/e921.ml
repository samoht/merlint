(** E921: dune-promoted MDX error blocks must not appear in source files. *)

type payload = { file : string; line : int }

(* Markdown form: a fenced [```mdx-error] block in a README/.md file. *)
let md_mdx_error_re = Re.compile Re.(seq [ bol; str "```mdx-error" ])

(* Odoc form: an [{err@mdx-error[ ... ]err}] block produced when dune promotes
   a failing mdx run inside a [{[ ... ]}] doc snippet. *)
let odoc_mdx_error_re = Re.compile (Re.str "{err@mdx-error")

let scan_file ctx path =
  match
    try Some (Context.file_content ctx path)
    with Sys_error _ | File_view.Analysis_error _ -> None
  with
  | None -> []
  | Some content ->
      let re =
        if Filename.check_suffix path ".md" then md_mdx_error_re
        else odoc_mdx_error_re
      in
      let line_of_offset off =
        let count = ref 1 in
        for i = 0 to off - 1 do
          if content.[i] = '\n' then incr count
        done;
        !count
      in
      Re.all re content
      |> List.map (fun g ->
          let line = line_of_offset (Re.Group.start g 0) in
          let display =
            Fpath.v path |> Loc.current_dir_relative |> Fpath.to_string
          in
          let loc =
            Location.v ~file:display ~start_line:line ~start_col:0
              ~end_line:line ~end_col:0
          in
          Issue.v ~loc { file = display; line })

(* In-scope sources to inspect: every [.md] / [.mld] from package + library
   doc files, plus every [.mli] from each library's [(modules ...)] spec.
   The index already enumerates these; we don't readdir. *)
let sources_in_scope ctx =
  let acc = ref [] in
  let add path = acc := Fpath.to_string path :: !acc in
  Context.index ctx |> Project_index.source_package_list
  |> List.iter (fun pkg ->
      List.iter
        (fun (d : Project_index.doc_file) -> add d.path)
        (Project_index.Package.doc_files pkg);
      Project_index.package_libraries pkg
      |> List.iter (fun lib ->
          List.iter
            (fun (d : Project_index.doc_file) -> add d.path)
            (Project_index.Library.doc_files lib);
          List.iter
            (fun fp ->
              if Filename.check_suffix (Fpath.to_string fp) ".mli" then add fp)
            (Project_index.Library.files lib)));
  List.sort_uniq String.compare !acc

let check (ctx : Context.project) =
  sources_in_scope ctx |> List.concat_map (scan_file ctx)

let pp ppf { file; line } =
  Fmt.pf ppf
    "%s:%d: dune-promoted mdx-error block found; fix the example so it \
     compiles and remove the error block"
    file line

let rule =
  Rule.v ~code:"E921" ~title:"Promoted MDX error block in source"
    ~hint:
      "A README.md, .mli, or .mld file contains an mdx-error block produced by \
       [dune promote] after a failing mdx run. The error output belongs in a \
       [.corrected] file for review, not in the committed source. Fix the \
       underlying example so it type-checks and remove the block."
    ~category:Rule.Documentation ~examples:[] ~pp (Project check)
