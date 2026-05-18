(** E807: Rust oracle missing Cargo.toml *)

type payload = { dir : string }

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      let scripts = Filename.concat d.path "scripts" in
      let has_rust =
        try
          let files = Fs.readdir scripts |> Array.to_list in
          List.exists (fun f -> Filename.check_suffix f ".rs") files
          ||
          let src = Filename.concat scripts "src" in
          Fs.file_exists src && Fs.is_directory src
          &&
            try
              Fs.readdir src |> Array.to_list
              |> List.exists (fun f -> Filename.check_suffix f ".rs")
            with Sys_error _ -> false
        with Sys_error _ -> false
      in
      let cargo = Filename.concat scripts "Cargo.toml" in
      let has_cargo = Fs.file_exists cargo in
      if has_rust && not has_cargo then
        Some (Issue.v ~loc:(Location.in_file cargo) { dir = d.path })
      else None)
    dirs

let pp ppf { dir } = Fmt.pf ppf "Rust oracle %s/scripts/ missing Cargo.toml" dir

let rule =
  Rule.v ~code:"E807" ~title:"Missing Cargo.toml" ~category:Interop_testing
    ~hint:
      "Rust oracles must pin the upstream crate in Cargo.toml with a tagged \
       version or git rev. This ensures reproducible trace generation without \
       depending on local checkouts."
    ~examples:[] ~pp (Project check)
