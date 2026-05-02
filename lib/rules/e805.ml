(** E805: Python oracle missing requirements.txt *)

type payload = { dir : string }

let check (ctx : Context.project) =
  let dirs = Interop.find_oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      let scripts = Filename.concat d.path "scripts" in
      let has_python =
        try
          Sys.readdir scripts |> Array.to_list
          |> List.exists (fun f -> Filename.check_suffix f ".py")
        with Sys_error _ -> false
      in
      let has_requirements =
        Sys.file_exists (Filename.concat scripts "requirements.txt")
      in
      if has_python && not has_requirements then
        let loc =
          Location.in_file (Filename.concat scripts "requirements.txt")
        in
        Some (Issue.v ~loc { dir = d.path })
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Python oracle %s/scripts/ missing requirements.txt" dir

let rule =
  Rule.v ~code:"E805" ~title:"Missing requirements.txt"
    ~category:Interop_testing
    ~hint:
      "Python oracles must pin dependencies in requirements.txt with exact \
       versions (e.g. crcmod==1.7). This ensures reproducible trace generation \
       without depending on local installs."
    ~examples:[] ~pp (Project check)
