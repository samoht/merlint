(** Wrapper for dune commands *)

let src = Logs.Src.create "merlint.dune" ~doc:"Dune interface"

module Log = (val Logs.src_log src : Logs.LOG)

(* Cache for dune describe output *)
let dune_describe_cache : (string, string) Hashtbl.t = Hashtbl.create 1

type describe = Sexplib0.Sexp.t
(** Parsed dune describe output *)

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

let parse_dune_describe sexp_str =
  try Parsexp.Single.parse_string_exn sexp_str
  with exn ->
    Log.err (fun m ->
        m "Failed to parse dune describe output: %s" (Printexc.to_string exn));
    Sexplib0.Sexp.List []

let describe project_root =
  match run_dune_describe project_root with
  | Error err ->
      Log.warn (fun m -> m "Could not run dune describe: %s" err);
      parse_dune_describe ""
  | Ok sexp_str -> parse_dune_describe sexp_str

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

(** Extract executable names (not their modules) from dune describe output *)
let extract_executables_from_sexp sexp =
  (* The structure is (root ...) (build_context ...) (executables ...) ... *)
  match sexp with
  | Sexplib0.Sexp.List items ->
      (* Look through items for executables *)
      List.concat_map
        (function
          | Sexplib0.Sexp.List
              (Sexplib0.Sexp.Atom "executables" :: exec_contents) ->
              (* Found an executables section *)
              List.concat_map
                (function
                  | Sexplib0.Sexp.List fields ->
                      (* Look for names field to get actual executable names *)
                      List.concat_map
                        (function
                          | Sexplib0.Sexp.List
                              (Sexplib0.Sexp.Atom "names"
                              :: [ Sexplib0.Sexp.List names ]) ->
                              List.filter_map
                                (function
                                  | Sexplib0.Sexp.Atom name ->
                                      Some (String.capitalize_ascii name)
                                  | _ -> None)
                                names
                          | _ -> [])
                        fields
                  | _ -> [])
                exec_contents
          | _ -> [])
        items
  | _ -> []

(** Get executable information for all files at once *)
let get_executable_info project_root =
  match run_dune_describe project_root with
  | Error err ->
      Log.warn (fun m -> m "Could not run dune describe: %s" err);
      (* Return empty set if dune describe fails *)
      []
  | Ok sexp_str -> (
      try
        let sexp = Parsexp.Single.parse_string_exn sexp_str in
        let executable_modules = extract_executables_from_sexp sexp in
        Log.debug (fun m ->
            m "Found executable modules: %s"
              (String.concat ", " executable_modules));
        executable_modules
      with exn ->
        Log.err (fun m ->
            m "Failed to parse dune describe output: %s"
              (Printexc.to_string exn));
        [])

(** Extract all source files from dune describe output *)
let extract_source_files sexp =
  let rec extract_modules = function
    | Sexplib0.Sexp.List
        (Sexplib0.Sexp.Atom "modules" :: [ Sexplib0.Sexp.List modules ]) ->
        (* Found modules section *)
        List.concat_map
          (function
            | Sexplib0.Sexp.List items ->
                (* Extract impl and intf fields *)
                List.concat_map
                  (function
                    | Sexplib0.Sexp.List
                        [
                          Sexplib0.Sexp.Atom "impl";
                          Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom path ];
                        ] ->
                        (* Convert build path to source path *)
                        let source_path =
                          if String.starts_with ~prefix:"_build/default/" path
                          then String.sub path 15 (String.length path - 15)
                          else path
                        in
                        [ source_path ]
                    | Sexplib0.Sexp.List
                        [
                          Sexplib0.Sexp.Atom "intf";
                          Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom path ];
                        ] ->
                        (* Convert build path to source path *)
                        let source_path =
                          if String.starts_with ~prefix:"_build/default/" path
                          then String.sub path 15 (String.length path - 15)
                          else path
                        in
                        [ source_path ]
                    | _ -> [])
                  items
            | _ -> [])
          modules
    | Sexplib0.Sexp.List items ->
        (* Recursively search in nested structures *)
        List.concat_map extract_modules items
    | _ -> []
  in

  let extract_from_stanzas = function
    | Sexplib0.Sexp.List items ->
        List.concat_map
          (function
            | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "library" :: lib_contents)
              ->
                (* Check if it's a local library *)
                let is_local =
                  List.exists
                    (function
                      | Sexplib0.Sexp.List
                          [
                            Sexplib0.Sexp.Atom "local";
                            Sexplib0.Sexp.Atom "true";
                          ] ->
                          true
                      | _ -> false)
                    lib_contents
                in
                if is_local then List.concat_map extract_modules lib_contents
                else []
            | Sexplib0.Sexp.List
                (Sexplib0.Sexp.Atom "executables" :: exec_contents) ->
                List.concat_map extract_modules exec_contents
            | Sexplib0.Sexp.List
                (Sexplib0.Sexp.Atom "executable" :: exec_contents) ->
                List.concat_map extract_modules exec_contents
            | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "test" :: test_contents) ->
                List.concat_map extract_modules test_contents
            | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "tests" :: test_contents)
              ->
                List.concat_map extract_modules test_contents
            | _ -> [])
          items
    | _ -> []
  in

  extract_from_stanzas sexp

(** Get all project source files using dune describe *)
let get_project_files project_root =
  match run_dune_describe project_root with
  | Error err ->
      Log.warn (fun m -> m "Could not run dune describe: %s" err);
      (* Return empty list if dune describe fails *)
      []
  | Ok sexp_str -> (
      try
        let sexp = Parsexp.Single.parse_string_exn sexp_str in
        let files = extract_source_files sexp in
        (* Remove duplicates and sort *)
        let unique_files = List.sort_uniq String.compare files in
        Log.debug (fun m ->
            m "Found %d source files from dune describe"
              (List.length unique_files));
        unique_files
      with exn ->
        Log.err (fun m ->
            m "Failed to parse dune describe output: %s"
              (Printexc.to_string exn));
        [])
