(** E802: Interop test missing committed traces *)

type payload = { dir : string; reason : string }

let dune_file ctx dir =
  let path = Filename.concat dir "dune" in
  try Context.file_content ctx path |> Dune.File.of_string |> Result.to_option
  with File_view.Analysis_error _ -> None

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs_for ctx in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if not d.has_traces then
        Some
          (Issue.v
             {
               dir = d.path;
               reason = "missing traces/ directory — traces must be committed";
             })
      else if d.has_dune then
        match dune_file ctx d.path with
        | Some dune when Dune.File.has_source_tree_dep dune "traces" -> None
        | _ ->
            Some
              (Issue.v
                 {
                   dir = d.path;
                   reason =
                     "dune test stanza missing (source_tree traces) dep — test \
                      must run from committed traces";
                 })
      else None)
    dirs

let pp ppf { dir; reason } = Fmt.pf ppf "Interop test %s: %s" dir reason

let rule =
  Rule.v ~code:"E802" ~title:"Interop test not replay-only"
    ~category:Interop_testing
    ~hint:
      "Traces must be committed to git. The test stanza must depend on \
       (source_tree traces) so tests run from traces alone — the external tool \
       is NOT required at test time. This is the 'generate once, replay \
       always' principle."
    ~examples:[] ~pp (Project check)
