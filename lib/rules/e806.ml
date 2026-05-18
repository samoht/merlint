(** E806: Go oracle missing go.mod *)

type payload = { dir : string }

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs_for ctx in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      let scripts = Filename.concat d.path "scripts" in
      let has_go =
        try
          Fs.readdir scripts |> Array.to_list
          |> List.exists (fun f -> Filename.check_suffix f ".go")
        with Sys_error _ -> false
      in
      let go_mod = Filename.concat scripts "go.mod" in
      let has_go_mod = Fs.file_exists go_mod in
      if has_go && not has_go_mod then
        Some (Issue.v ~loc:(Location.in_file go_mod) { dir = d.path })
      else None)
    dirs

let pp ppf { dir } = Fmt.pf ppf "Go oracle %s/scripts/ missing go.mod" dir

let rule =
  Rule.v ~code:"E806" ~title:"Missing go.mod" ~category:Interop_testing
    ~hint:
      "Go oracles must pin the upstream module in go.mod with a tagged version \
       or pseudo-version. This ensures reproducible trace generation without \
       depending on $GOPATH or local clones."
    ~examples:[] ~pp (Project check)
