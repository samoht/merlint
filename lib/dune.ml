(** Wrapper for dune commands *)

let src = Logs.Src.create "merlint.dune" ~doc:"Dune interface"

module Log = (val Logs.src_log src : Logs.LOG)

(* Cache for dune describe output *)
let dune_describe_cache : (string, string) Hashtbl.t = Hashtbl.create 1

type stanza_type = Library | Executable | Test

type stanza_info = {
  name : string;
  stanza_type : stanza_type;
  modules : string list;
}

let run_dune_describe project_root =
  (* Check cache first *)
  match Hashtbl.find_opt dune_describe_cache project_root with
  | Some cached ->
      Log.debug (fun m ->
          m "Using cached dune describe output for %s" project_root);
      Ok cached
  | None -> (
      let cmd =
        Fmt.str "cd %s && dune describe" (Filename.quote project_root)
      in
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
          (* Cache the result *)
          Hashtbl.add dune_describe_cache project_root sexp_str;
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
          Error (Fmt.str "Dune describe was stopped by signal %d" n))

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

let is_test_module module_name stanza_info =
  (* Check if this module belongs to a test or executable stanza *)
  List.exists
    (fun info ->
      match info.stanza_type with
      | Test | Executable -> List.mem module_name info.modules
      | Library -> false)
    stanza_info

let is_executable project_root ml_file =
  (* Only use dune describe to get actual stanza information *)
  match run_dune_describe project_root with
  | Error err ->
      Log.warn (fun m -> m "Could not run dune describe: %s" err);
      (* If dune describe fails, we can't determine if it's an executable *)
      false
  | Ok sexp_str ->
      (* Parse the s-expression and check if file belongs to executable stanza *)
      let module_name = Filename.basename (Filename.remove_extension ml_file) in
      let module_name_capitalized = String.capitalize_ascii module_name in
      (* Use Re to find executable or test stanzas *)
      let executables_regex = Re.compile (Re.str "executables") in
      let tests_regex = Re.compile (Re.str "tests") in
      let module_regex = Re.compile (Re.str module_name_capitalized) in
      let has_executable_stanza =
        (Re.execp executables_regex sexp_str || Re.execp tests_regex sexp_str)
        && Re.execp module_regex sexp_str
      in
      has_executable_stanza

(** Clear the dune describe cache *)
let clear_cache () = Hashtbl.clear dune_describe_cache

(** Get executable information for all files at once *)
let get_executable_info project_root =
  match run_dune_describe project_root with
  | Error err ->
      Log.warn (fun m -> m "Could not run dune describe: %s" err);
      (* Return empty set if dune describe fails *)
      []
  | Ok sexp_str ->
      (* Parse executable and test modules from the sexp *)
      let executables_regex = Re.compile (Re.str "executables") in
      let tests_regex = Re.compile (Re.str "tests") in
      let module_regex =
        Re.compile
          (Re.seq
             [
               Re.str "\"";
               Re.group (Re.rep1 (Re.alt [ Re.alnum; Re.char '_' ]));
               Re.str "\"";
             ])
      in

      let has_executables =
        Re.execp executables_regex sexp_str || Re.execp tests_regex sexp_str
      in

      if has_executables then
        Re.all module_regex sexp_str |> List.map (fun m -> Re.Group.get m 1)
      else []
