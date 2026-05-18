(** E800: Missing generate.sh in interop test *)

type payload = { dir : string }

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_scripts then
        let generate_sh = Filename.concat d.path "scripts/generate.sh" in
        if not (Fs.file_exists generate_sh) then
          Some (Issue.v ~loc:(Location.in_file generate_sh) { dir = d.path })
        else None
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s/scripts/ is missing generate.sh" dir

let rule =
  Rule.v ~code:"E800" ~title:"Missing generate.sh" ~category:Interop_testing
    ~hint:
      "Every interop test must have scripts/generate.sh as the single entry \
       point for trace regeneration via `dune build @regen-traces`."
    ~examples:[] ~pp (Project check)
