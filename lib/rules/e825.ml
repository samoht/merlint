(** E825: Interop test uses CSV traces but dune lacks csv dependency *)

type payload = { dir : string }

let check (ctx : Context.project) =
  let dirs = Interop.find_oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_traces && d.has_dune then
        let traces = Filename.concat d.path "traces" in
        let has_csv =
          try
            Sys.readdir traces |> Array.to_list
            |> List.exists (fun f -> Filename.check_suffix f ".csv")
          with Sys_error _ -> false
        in
        if has_csv then
          let dune = Interop.dune_content d.path in
          if not (Astring.String.is_infix ~affix:"csv" dune) then
            let loc = Location.in_file (Filename.concat d.path "dune") in
            Some (Issue.v ~loc { dir = d.path })
          else None
        else None
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s has CSV traces but dune lacks csv dependency" dir

let rule =
  Rule.v ~code:"E825" ~title:"Missing csv dependency" ~category:Interop_testing
    ~hint:
      "Interop tests with CSV traces should use csv for parsing. Add csv to \
       the (libraries ...) in the dune file and use Csv.decode_file with a Row \
       codec."
    ~examples:[] ~pp (Project check)
