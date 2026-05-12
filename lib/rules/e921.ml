(** E921: dune-promoted MDX error blocks must not appear in source files. *)

type payload = { file : string; line : int }

(* Markdown form: a fenced [```mdx-error] block in a README/.md file. *)
let md_mdx_error_re = Re.compile Re.(seq [ bol; str "```mdx-error" ])

(* Odoc form: an [{err@mdx-error[ ... ]err}] block produced when dune promotes
   a failing mdx run inside a [{[ ... ]}] doc snippet. *)
let odoc_mdx_error_re = Re.compile (Re.str "{err@mdx-error")

let scan_file path =
  try
    let ic = open_in path in
    Fun.protect
      ~finally:(fun () -> close_in ic)
      (fun () ->
        let content = really_input_string ic (in_channel_length ic) in
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
            Issue.v ~loc { file = path; line }))
  with Sys_error _ -> []

let rec walk dir =
  let entries = try Sys.readdir dir |> Array.to_list with Sys_error _ -> [] in
  List.concat_map
    (fun entry ->
      if String.length entry > 0 && (entry.[0] = '.' || entry.[0] = '_') then []
      else
        let path = Filename.concat dir entry in
        if try Sys.is_directory path with _ -> false then walk path
        else if
          Filename.check_suffix path ".md"
          || Filename.check_suffix path ".mli"
          || Filename.check_suffix path ".mld"
        then scan_file path
        else [])
    entries

let check (ctx : Context.project) = walk ctx.project_root

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
