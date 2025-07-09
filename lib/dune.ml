(** Wrapper for dune commands *)

let src = Logs.Src.create "merlint.dune" ~doc:"Dune interface"

module Log = (val Logs.src_log src : Logs.LOG)

type stanza_type = Library | Executable | Test

type stanza_info = {
  name : string;
  stanza_type : stanza_type;
  modules : string list;
}

let run_dune_describe project_root =
  let cmd = Fmt.str "cd %s && dune describe" (Filename.quote project_root) in
  Log.debug (fun m -> m "Running dune describe command: %s" cmd);
  let ic = Unix.open_process_in cmd in
  let rec read_all acc =
    try
      let line = input_line ic in
      read_all (line :: acc)
    with End_of_file -> List.rev acc
  in
  let output = read_all [] in
  let status = Unix.close_process_in ic in
  match status with
  | Unix.WEXITED 0 ->
      let sexp_str = String.concat "\n" output in
      Log.debug (fun m ->
          m "Dune describe successful, output length: %d"
            (String.length sexp_str));
      Ok sexp_str
  | Unix.WEXITED 127 ->
      Log.err (fun m -> m "dune not found");
      Error "dune not found. Please ensure dune is installed"
  | Unix.WEXITED code ->
      Log.err (fun m -> m "Dune describe failed with exit code %d" code);
      Error (Fmt.str "Dune describe failed with exit code %d" code)
  | Unix.WSIGNALED n ->
      Log.err (fun m -> m "Dune describe killed by signal %d" n);
      Error (Fmt.str "Dune describe was killed by signal %d" n)
  | Unix.WSTOPPED n ->
      Log.err (fun m -> m "Dune describe stopped by signal %d" n);
      Error (Fmt.str "Dune describe was stopped by signal %d" n)

let ensure_project_built project_root =
  (* Check if _build directory exists *)
  let build_dir = Filename.concat project_root "_build" in
  if not (Sys.file_exists build_dir) then (
    Log.info (fun m -> m "No _build directory found, running 'dune build'");
    let cmd = Fmt.str "cd %s && dune build" (Filename.quote project_root) in
    match Unix.system cmd with
    | Unix.WEXITED 0 ->
        Log.info (fun m -> m "Successfully built project");
        Ok ()
    | Unix.WEXITED code ->
        Log.err (fun m -> m "Dune build failed with exit code %d" code);
        Error (Fmt.str "Dune build failed with exit code %d" code)
    | Unix.WSIGNALED n ->
        Log.err (fun m -> m "Dune build killed by signal %d" n);
        Error (Fmt.str "Dune build was killed by signal %d" n)
    | Unix.WSTOPPED n ->
        Log.err (fun m -> m "Dune build stopped by signal %d" n);
        Error (Fmt.str "Dune build was stopped by signal %d" n))
  else (
    Log.debug (fun m -> m "_build directory already exists");
    Ok ())

let is_test_or_binary module_name stanza_info =
  (* Check if this module belongs to a test or executable stanza *)
  List.exists
    (fun info ->
      match info.stanza_type with
      | Test | Executable -> List.mem module_name info.modules
      | Library -> false)
    stanza_info
