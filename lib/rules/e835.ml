(** E835: pip install --break-system-packages in interop script *)

type payload = { dir : string; file : string }

let check (ctx : Context.project) =
  let dirs = Interop.find_oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      let scripts = Filename.concat d.path "scripts" in
      if not (Sys.file_exists scripts) then None
      else
        let files =
          try Sys.readdir scripts |> Array.to_list with Sys_error _ -> []
        in
        let bad =
          List.filter_map
            (fun f ->
              if Filename.check_suffix f ".sh" || Filename.check_suffix f ".py"
              then
                let content = Interop.read_file (Filename.concat scripts f) in
                if
                  Astring.String.is_infix ~affix:"--break-system-packages"
                    content
                then Some f
                else None
              else None)
            files
        in
        match bad with
        | [] -> None
        | file :: _ -> Some (Issue.v { dir = d.path; file }))
    dirs

let pp ppf { dir; file } =
  Fmt.pf ppf "%s/scripts/%s uses --break-system-packages" dir file

let rule =
  Rule.v ~code:"E835" ~title:"pip install --break-system-packages"
    ~category:Interop_testing
    ~hint:
      "Python deps must live in a venv. Never use pip install \
       --break-system-packages. The generate.sh wrapper should create/reuse a \
       venv automatically."
    ~examples:[] ~pp (Project check)
