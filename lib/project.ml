(** Project root discovery *)

(** Find the project root by looking for dune-project file *)
let root path =
  let rec find_root current =
    let dune_project = Filename.concat current "dune-project" in
    if Sys.file_exists dune_project then current
    else
      let parent = Filename.dirname current in
      if parent = current then
        (* We've reached the root of the filesystem *)
        Sys.getcwd ()
      else find_root parent
  in
  if Sys.file_exists path && Sys.is_directory path then find_root path
  else if Sys.file_exists path then find_root (Filename.dirname path)
  else Sys.getcwd ()
