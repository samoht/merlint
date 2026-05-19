let source_libraries index =
  Project_index.source_packages_nodes index
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

let library_module_map index =
  source_libraries index
  |> List.fold_left
       (fun acc lib ->
         let lib_name = Project_index.Library.local_name lib in
         List.fold_left
           (fun acc file -> add_module_lib acc lib_name file)
           acc
           (Project_index.Library.files lib))
       []

let resolve_library index name =
  match
    source_libraries index
    |> List.find_opt (fun lib ->
           Project_index.Library.public_name lib = Some name)
  with
  | Some lib -> Project_index.Library.local_name lib
  | None -> name

let test_file_library module_map basename =
  if String.starts_with ~prefix:"test_" basename then
    let tested_module = String.sub basename 5 (String.length basename - 5) in
    match List.assoc_opt tested_module module_map with
    | Some [ lib ] -> Some lib
    | _ -> None
  else None
