(** Shared helpers for E8xx interop testing rules. *)

type oracle_dir = {
  path : string;
  package : string;
  tool : string;
  has_scripts : bool;
  has_traces : bool;
  has_test_ml : bool;
  has_dune : bool;
}

let oracle_of_tool pkg interop tool =
  let path = Filename.concat interop tool in
  if not (Fs.is_directory path) then None
  else
    let display_path =
      Fpath.v path |> Loc.current_dir_relative |> Fpath.to_string
    in
    Some
      {
        path = display_path;
        package = pkg;
        tool;
        has_scripts = Fs.file_exists (Filename.concat path "scripts");
        has_traces = Fs.file_exists (Filename.concat path "traces");
        has_test_ml = Fs.file_exists (Filename.concat path "test.ml");
        has_dune = Fs.file_exists (Filename.concat path "dune");
      }

let package_oracles pkg pkg_dir =
  let interop = Filename.concat pkg_dir "test/interop" in
  if not (Fs.is_directory interop) then []
  else
    Fs.readdir_or_empty interop |> List.filter_map (oracle_of_tool pkg interop)

let path_has_interop path =
  let parts = Fpath.segs path in
  let rec aux = function
    | "test" :: "interop" :: _ -> true
    | _ :: rest -> aux rest
    | [] -> false
  in
  aux parts

(* Reach for the in-scope packages via [Project_index] instead of walking the
   monorepo root: many rules call [oracle_dirs] per run, and scoping cuts the
   FS walk from "every package" down to "the analyse-set". *)
let oracle_dirs_uncached index =
  let package_dirs =
    Project_index.source_package_list index
    |> List.filter_map (fun pkg ->
        Option.map
          (fun dir -> (Project_index.Package.name pkg, Fpath.to_string dir))
          (Project_index.Package.source_dir pkg))
  in
  let package_oracles =
    List.concat_map (fun (name, dir) -> package_oracles name dir) package_dirs
  in
  let dune_oracles =
    Project_index.dune_dirs index
    |> List.filter path_has_interop
    |> List.map (fun dir ->
        let path = Fpath.to_string dir in
        let tool = Filename.basename path in
        {
          path = Fpath.v path |> Loc.current_dir_relative |> Fpath.to_string;
          package = "";
          tool;
          has_scripts = Fs.file_exists (Filename.concat path "scripts");
          has_traces = Fs.file_exists (Filename.concat path "traces");
          has_test_ml = Fs.file_exists (Filename.concat path "test.ml");
          has_dune = true;
        })
  in
  List.sort_uniq
    (fun a b -> String.compare a.path b.path)
    (package_oracles @ dune_oracles)

(* Cache the walk by index identity -- 10+ E8xx rules call this per run and
   the FS layout doesn't change between rule invocations. *)
let oracle_dirs_cache : (Project_index.t, oracle_dir list) Hashtbl.t =
  Hashtbl.create 4

let oracle_dirs index =
  match Hashtbl.find_opt oracle_dirs_cache index with
  | Some xs -> xs
  | None ->
      let xs = oracle_dirs_uncached index in
      Hashtbl.replace oracle_dirs_cache index xs;
      xs

let oracle_dirs_for ctx = oracle_dirs (Context.index ctx)

let script_contains ~dir ~file ~affix =
  if Filename.check_suffix file ".sh" || Filename.check_suffix file ".py" then
    try
      let content = Fs.read_file (Filename.concat dir file) in
      Astring.String.is_infix ~affix content
    with Sys_error _ -> false
  else false
