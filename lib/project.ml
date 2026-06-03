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

module Query = struct
  let source_libraries index =
    Project_index.source_package_list index
    |> List.concat_map Project_index.package_libraries

  let add_module_lib acc lib_name file =
    let s = Fpath.to_string file in
    if File_kind.is_ml s then
      let module_name = Filename.remove_extension (Filename.basename s) in
      match List.assoc_opt module_name acc with
      | Some libs ->
          (module_name, lib_name :: libs) :: List.remove_assoc module_name acc
      | None -> (module_name, [ lib_name ]) :: acc
    else acc

  let library_module_map_of libs =
    List.fold_left
      (fun acc lib ->
        let lib_name = Project_index.Library.local_name lib in
        List.fold_left
          (fun acc file -> add_module_lib acc lib_name file)
          acc
          (Project_index.Library.files lib))
      [] libs

  let library_module_map index = library_module_map_of (source_libraries index)

  let resolve_library index name =
    Project_index.resolve_public_library index name

  let test_file_library module_map basename =
    if String.starts_with ~prefix:"test_" basename then
      let tested_module = String.sub basename 5 (String.length basename - 5) in
      match List.assoc_opt tested_module module_map with
      | Some [ lib ] -> Some lib
      | _ -> None
    else None
end
