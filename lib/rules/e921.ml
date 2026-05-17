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
          let loc =
            Location.v ~file:path ~start_line:line ~start_col:0 ~end_line:line
              ~end_col:0
          in
          Issue.v ~loc { file = path; line })

let rec walk ctx dir =
  let entries = try Sys.readdir dir |> Array.to_list with Sys_error _ -> [] in
  List.concat_map
    (fun entry ->
      let path = Filename.concat dir entry in
      let is_dir = try Sys.is_directory path with Sys_error _ -> false in
      if is_dir then
        if Dune_describe.skippable_subdir ~parent_dir:(Fpath.v dir) entry then
          []
        else walk ctx path
      else if
        Filename.check_suffix path ".md"
        || Filename.check_suffix path ".mli"
        || Filename.check_suffix path ".mld"
      then scan_file ctx path
      else [])
    entries

let check (ctx : Context.project) = walk ctx ctx.project_root

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
