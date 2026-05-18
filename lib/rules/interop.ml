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

let oracle_dirs_uncached project_root =
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let is_dir path = try Sys.is_directory path with Sys_error _ -> false in
  let oracle_of_tool pkg interop tool =
    let path = Filename.concat interop tool in
    if not (is_dir path) then None
    else
      let display_path =
        Fpath.v path |> Loc.current_dir_relative |> Fpath.to_string
      in
      Some
        {
          path = display_path;
          package = pkg;
          tool;
          has_scripts = Sys.file_exists (Filename.concat path "scripts");
          has_traces = Sys.file_exists (Filename.concat path "traces");
          has_test_ml = Sys.file_exists (Filename.concat path "test.ml");
          has_dune = Sys.file_exists (Filename.concat path "dune");
        }
  in
  let package_oracles pkg =
    let pkg_dir = Filename.concat project_root pkg in
    let interop = Filename.concat (Filename.concat pkg_dir "test") "interop" in
    if List.mem pkg [ "_build"; ".git" ] || not (is_dir interop) then []
    else try_readdir interop |> List.filter_map (oracle_of_tool pkg interop)
  in
  try_readdir project_root |> List.concat_map package_oracles

(* Cache the walk by [project_root] -- 10+ E8xx rules call this per run and
   the FS layout doesn't change between rule invocations. *)
let oracle_dirs_cache : (string, oracle_dir list) Hashtbl.t = Hashtbl.create 4

let oracle_dirs project_root =
  match Hashtbl.find_opt oracle_dirs_cache project_root with
  | Some xs -> xs
  | None ->
      let xs = oracle_dirs_uncached project_root in
      Hashtbl.replace oracle_dirs_cache project_root xs;
      xs

let read_file path =
  try
    let ic = open_in path in
    Fun.protect
      ~finally:(fun () -> close_in ic)
      (fun () ->
        let n = in_channel_length ic in
        really_input_string ic n)
  with Sys_error _ -> ""

let dune_content dir = read_file (Filename.concat dir "dune")
let test_content dir = read_file (Filename.concat dir "test.ml")
