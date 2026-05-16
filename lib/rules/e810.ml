(** E810: Missing regen-traces alias in dune *)

type payload = { dir : string }

let dune_file ctx dir =
  let path = Filename.concat dir "dune" in
  try
    File_view.content (Context.file_view ctx path)
    |> Dune.File.of_string |> Result.to_option
  with File_view.Analysis_error _ -> None

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_dune then
        match dune_file ctx d.path with
        | Some dune
          when Dune.File.has_rule_alias dune "regen-traces"
               || Dune.File.has_rule_alias dune "regen_traces" ->
            None
        | _ ->
            let loc = Location.in_file (Filename.concat d.path "dune") in
            Some (Issue.v ~loc { dir = d.path })
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s/dune missing regen-traces alias" dir

let rule =
  Rule.v ~code:"E810" ~title:"Missing regen-traces alias"
    ~category:Interop_testing
    ~hint:
      "Every interop test dune file must define a regen-traces alias as the \
       single trigger for refreshing traces: `(rule (alias regen-traces) \
       ...)`."
    ~examples:[] ~pp (Project check)
