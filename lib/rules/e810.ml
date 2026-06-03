(** E810: Missing regen alias in traces/dune *)

type payload = { dir : string }

let traces_dune ctx (dir : Interop.oracle_dir) =
  try
    Context.file_content ctx Context.Path.(dir.path / "traces" / "dune")
    |> Dune.File.of_string |> Result.to_option
  with File_view.Analysis_error _ -> None

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs_for ctx in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_traces then
        match traces_dune ctx d with
        | Some dune when Dune.File.has_rule_alias dune "regen" -> None
        | _ ->
            let loc =
              Location.in_file (Interop.display_child d "traces/dune")
            in
            Some (Issue.v ~loc { dir = Interop.display d })
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s/traces/dune missing regen alias" dir

let rule =
  Rule.v ~code:"E810" ~title:"Missing regen alias" ~category:Interop_testing
    ~hint:
      "traces/dune must define the trace-regeneration rule as `(rule (alias \
       regen) (mode promote) (enabled_if (= %{env:REGEN=0} 1)) ...)`, the \
       single trigger for refreshing traces: `REGEN=1 dune build @regen`."
    ~examples:[] ~pp (Project check)
