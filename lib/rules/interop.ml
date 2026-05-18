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

let oracle_dirs project_root =
  (* Walk <pkg>/test/interop/<tool>/ directories *)
  let results = ref [] in
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let packages = try_readdir project_root in
  List.iter
    (fun pkg ->
      let pkg_dir = Filename.concat project_root pkg in
      if Sys.is_directory pkg_dir && pkg <> "_build" && pkg <> ".git" then
        let interop =
          Filename.concat (Filename.concat pkg_dir "test") "interop"
        in
        if Sys.file_exists interop && Sys.is_directory interop then
          let tools = try_readdir interop in
          List.iter
            (fun tool ->
              let path = Filename.concat interop tool in
              if Sys.is_directory path then
                let display_path =
                  Fpath.v path |> Loc.relative_to_cwd |> Fpath.to_string
                in
                results :=
                  {
                    path = display_path;
                    package = pkg;
                    tool;
                    has_scripts =
                      Sys.file_exists (Filename.concat path "scripts");
                    has_traces = Sys.file_exists (Filename.concat path "traces");
                    has_test_ml =
                      Sys.file_exists (Filename.concat path "test.ml");
                    has_dune = Sys.file_exists (Filename.concat path "dune");
                  }
                  :: !results)
            tools)
    packages;
  !results

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
