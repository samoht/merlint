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

type link = { checkout : Fpath.t; workspace : Fpath.t; path : Fpath.t }

let err fmt = Fmt.kstr (fun s -> Error s) fmt

let err_not_a_root workspace =
  err
    "merlint.toml declares workspace %a, which is not a Dune root: it has \
     neither a dune-workspace nor a dune-project file."
    Fpath.pp workspace

let err_not_linked ~workspace ~checkout =
  err
    "merlint.toml declares workspace %a, whose source tree does not reach %a. \
     The workspace builds this checkout only if one of its directories is this \
     one."
    Fpath.pp workspace Fpath.pp checkout

let real path = try Some (Unix.realpath path) with Unix.Unix_error _ -> None
let dir_path path = Fpath.(v path |> normalize |> to_dir_path)

(* The checkout's own Dune root, as the directory the declaration is resolved
   against. *)
let checkout_root path = dir_path (root path)

let is_dune_root dir =
  let has name = Sys.file_exists Fpath.(to_string (dir / name)) in
  has "dune-workspace" || has "dune-project"

(* The closest [merlint.toml] that declares a workspace wins, like every other
   scalar setting. The value is a path relative to the file that declares it,
   resolved through the real directory so that the same file read through the
   workspace's own symlink names the same workspace. *)
let declared_workspace path =
  config_files path
  |> List.filter_map (fun config ->
      match Config_parser.parse_file config with
      | None -> None
      | Some parsed ->
          List.find_map
            (fun (key, value) ->
              if key = "workspace" then Some (config, value) else None)
            parsed.Config_parser.settings)
  |> List.rev
  |> function
  | [] -> None
  | (config, value) :: _ ->
      let dir = Filename.dirname config in
      let declared_in = Option.value ~default:dir (real dir) in
      Some (dir_path Fpath.(to_string (v declared_in // v value)))

(* Where [workspace] reaches [checkout]: the entry that resolves to it, tried
   under the checkout's own name first since that is what a link is normally
   called. *)
let linked_path ~workspace ~checkout =
  match real (Fpath.to_string checkout) with
  | None -> None
  | Some target ->
      let ws = Fpath.to_string workspace in
      let resolves name =
        match real (Filename.concat ws name) with
        | Some path -> String.equal path target
        | None -> false
      in
      let named = Fpath.basename (Fpath.rem_empty_seg checkout) in
      if resolves named then Some Fpath.(workspace / named)
      else
        let entries = try Sys.readdir ws with Sys_error _ -> [||] in
        Array.sort String.compare entries;
        Array.to_list entries |> List.find_opt resolves
        |> Option.map (fun entry -> Fpath.(workspace / entry))

let same_dir a b =
  match (real (Fpath.to_string a), real (Fpath.to_string b)) with
  | Some a, Some b -> String.equal a b
  | _ -> Fpath.equal a b

let workspace_link path =
  match declared_workspace path with
  | None -> Ok None
  | Some workspace -> (
      let checkout = checkout_root path in
      if same_dir workspace checkout then Ok None
      else if not (is_dune_root workspace) then err_not_a_root workspace
      else
        match linked_path ~workspace ~checkout with
        | None -> err_not_linked ~workspace ~checkout
        | Some path ->
            Ok (Some { checkout; workspace; path = Fpath.to_dir_path path }))

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
