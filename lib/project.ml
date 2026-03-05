(** Project root discovery *)

let start_dir path =
  if Sys.file_exists path && Sys.is_directory path then path
  else if Sys.file_exists path then Filename.dirname path
  else Sys.getcwd ()

(** Walk upward from [start], calling [f dir acc] on each directory until the
    filesystem root is reached. *)
let walk_up ~f ~init start =
  let rec go current acc =
    let acc = f current acc in
    let parent = Filename.dirname current in
    if parent = current then acc else go parent acc
  in
  go start init

(** Find the nearest project root by looking for dune-project. *)
let root path =
  let start = start_dir path in
  let rec find current =
    if Sys.file_exists (Filename.concat current "dune-project") then current
    else
      let parent = Filename.dirname current in
      if parent = current then Sys.getcwd () else find parent
  in
  find start

(** Find the workspace root (outermost dune-project) and collect all .merlint
    config files from [path] up to the workspace root. Returns
    [(ws_root, config_files)] where config files are ordered outermost-first. *)
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
        let p = Filename.concat dir ".merlint" in
        if Sys.file_exists p then p :: configs else configs
      in
      (ws_root, configs))

let workspace_root path = fst (workspace_root_and_configs path)
let config_files path = snd (workspace_root_and_configs path)
