(** E835: pip install --break-system-packages in interop script *)

type payload = { dir : string; file : string }

let script_has_break_system_packages scripts file =
  if Filename.check_suffix file ".sh" || Filename.check_suffix file ".py" then
    let content = Interop.read_file (Filename.concat scripts file) in
    Astring.String.is_infix ~affix:"--break-system-packages" content
  else false

let first_bad_script scripts =
  let entries =
    try Fs.readdir scripts |> Array.to_list with Sys_error _ -> []
  in
  List.find_opt (script_has_break_system_packages scripts) entries

let issue_for_oracle (d : Interop.oracle_dir) =
  let scripts = Filename.concat d.path "scripts" in
  if not (Fs.file_exists scripts) then None
  else
    match first_bad_script scripts with
    | None -> None
    | Some file ->
        let loc = Location.in_file (Filename.concat scripts file) in
        Some (Issue.v ~loc { dir = d.path; file })

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs_for ctx in
  List.filter_map issue_for_oracle dirs

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
