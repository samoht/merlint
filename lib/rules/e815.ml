(** E815: Interop trace-regeneration rule not REGEN-gated *)

type payload = { dir : string; file : string }

let parse ctx path =
  try
    Context.file_content ctx path
    |> Dune.of_string (Dune.Codec.file ())
    |> Result.to_option
  with File_view.Analysis_error _ -> None

(* The rule that runs scripts/generate.sh regenerates the committed traces. It
   must be guarded by (enabled_if (= %{env:REGEN=0} 1)) so the rule does not
   exist during a normal `dune test`: otherwise its (mode promote) target is
   rebuilt whenever the test depends on (source_tree traces), i.e. `dune test`
   (and CI) would run the external oracle. Regen is REGEN=1 dune build
   @traces. *)
let runs_generate_sh rule =
  List.exists
    (List.exists (fun arg -> Filename.basename arg = "generate.sh"))
    (Dune.File.Rule.run_actions rule)

let regen_gated rule = Dune.File.Rule.enabled_if_env_var rule = Some "REGEN"

let check (ctx : Context.project) =
  Interop.oracle_dirs_for ctx
  |> List.concat_map (fun (d : Interop.oracle_dir) ->
      [
        ("dune", Path.(d.path / "dune"));
        ("traces/dune", Path.(d.path / "traces" / "dune"));
      ]
      |> List.concat_map (fun (rel, path) ->
          match parse ctx path with
          | None -> []
          | Some dune ->
              Dune.File.rules dune
              |> List.filter (fun r ->
                  runs_generate_sh r && not (regen_gated r))
              |> List.map (fun _ ->
                  let loc = Location.in_file (Interop.display_child d rel) in
                  Issue.v ~loc { dir = Interop.display d; file = rel })))

let pp ppf { dir; file } =
  Fmt.pf ppf
    "Interop test %s/%s runs generate.sh without an (enabled_if (= \
     %%{env:REGEN=0} 1)) guard"
    dir file

let rule =
  Rule.v ~code:"E815" ~title:"Interop regen rule not REGEN-gated"
    ~category:Interop_testing
    ~hint:
      "The rule that regenerates traces must use (mode promote) guarded by \
       (enabled_if (= %{env:REGEN=0} 1)), living in traces/dune under (alias \
       regen), so a normal `dune test` leaves the traces as committed source \
       and never runs the external oracle. Regenerate with `REGEN=1 dune build \
       @regen`."
    ~examples:[] ~pp (Project check)
