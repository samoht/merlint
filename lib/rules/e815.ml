(** E815: REGEN_TRACES sentinel in dune *)

type payload = { dir : string }

let dune_file ctx dir =
  let path = Filename.concat dir "dune" in
  try Context.file_content ctx path |> Dune.File.of_string |> Result.to_option
  with File_view.Analysis_error _ -> None

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_dune then
        match dune_file ctx d.path with
        | Some dune
          when List.exists
                 (fun rule ->
                   Dune.File.Rule.enabled_if_env_var rule = Some "REGEN_TRACES")
                 (Dune.File.rules dune) ->
            let loc = Location.in_file (Filename.concat d.path "dune") in
            Some (Issue.v ~loc { dir = d.path })
        | _ -> None
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s/dune uses REGEN_TRACES sentinel" dir

let rule =
  Rule.v ~code:"E815" ~title:"REGEN_TRACES sentinel in dune"
    ~category:Interop_testing
    ~hint:
      "The regen-traces alias should be the single entry point — no \
       REGEN_TRACES=1 env var sentinel. Remove the (enabled_if ...) guard so \
       `dune build @regen-traces` works directly."
    ~examples:[] ~pp (Project check)
