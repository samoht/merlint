(** Project root discovery *)

let start_dir = Merlin.Project.start_dir
let walk_up = Merlin.Project.walk_up
let root = Merlin.Project.root
let workspace_root = Merlin.Project.workspace_root

let workspace_root_and_configs path =
  let start = start_dir path in
  walk_up start
    ~init:(Sys.getcwd (), [])
    ~f:(fun dir (ws_root, configs) ->
      let ws_root =
        if Sys.file_exists (Filename.concat dir "dune-project") then dir
        else ws_root
      in
      let configs =
        let p = Filename.concat dir "merlint.toml" in
        if Sys.file_exists p then p :: configs else configs
      in
      (ws_root, configs))

let config_files path = snd (workspace_root_and_configs path)
