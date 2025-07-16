(** Wrapper for dune commands *)

let src = Logs.Src.create "merlint.dune" ~doc:"Dune interface"

module Log = (val Logs.src_log src : Logs.LOG)

type describe = Sexplib0.Sexp.t
(** Parsed dune describe output *)

let run_dune_describe project_root =
  let cmd = Fmt.str "dune describe --root %s" (Filename.quote project_root) in
  match Command.run cmd with
  | Ok output ->
      Log.debug (fun m ->
          m "Dune describe successful, output length: %d" (String.length output));
      Ok output
  | Error msg ->
      Log.err (fun m -> m "Dune describe failed: %s" msg);
      Error msg

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
let get_executable_info dune_describe =
  let executable_modules = extract_executables_from_sexp dune_describe in
  Log.debug (fun m ->
      m "Found executable modules: %s" (String.concat ", " executable_modules));
  executable_modules

let is_executable dune_describe ml_file =
  (* Get executable modules and check if this file is one of them *)
  let executable_modules = get_executable_info dune_describe in
  let module_name = Filename.basename (Filename.remove_extension ml_file) in
  let module_name_capitalized = String.capitalize_ascii module_name in
  List.mem module_name_capitalized executable_modules

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
                        (Sexplib0.Sexp.Atom "impl" :: Sexplib0.Sexp.Atom path :: _) ->
                        (* Convert build path to source path *)
                        let source_path =
                          if String.starts_with ~prefix:"_build/default/" path
                          then String.sub path 15 (String.length path - 15)
                          else path
                        in
                        [ source_path ]
                    | Sexplib0.Sexp.List
                        (Sexplib0.Sexp.Atom "intf" :: Sexplib0.Sexp.Atom path :: _) ->
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
            | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "library" :: rest) -> (
                match rest with
                | [ Sexplib0.Sexp.List lib_contents ] ->
                    (* Library stanza has nested list structure *)
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
                    if is_local then
                      List.concat_map extract_modules lib_contents
                    else []
                | _ -> [])
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
let get_project_files dune_describe =
  try
    let files = extract_source_files dune_describe in
    (* Remove duplicates and sort *)
    let unique_files = List.sort_uniq String.compare files in
    Log.debug (fun m ->
        m "Found %d source files from dune describe" (List.length unique_files));
    unique_files
  with exn ->
    Log.err (fun m ->
        m "Failed to extract source files: %s" (Printexc.to_string exn));
    []

let get_lib_modules dune_describe =
  let rec extract = function
    | Sexplib0.Sexp.List items ->
        List.concat_map
          (function
            | Sexplib0.Sexp.List
                [ Sexplib0.Sexp.Atom "library"; Sexplib0.Sexp.List lib_contents ]
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
                if is_local then
                  (* Extract modules from library *)
                  List.concat_map
                    (function
                      | Sexplib0.Sexp.List
                          (Sexplib0.Sexp.Atom "modules" :: [ Sexplib0.Sexp.List modules ]) ->
                          List.concat_map
                            (function
                              | Sexplib0.Sexp.List module_fields ->
                                  (* Look for name field in module *)
                                  List.filter_map
                                    (function
                                      | Sexplib0.Sexp.List
                                          (Sexplib0.Sexp.Atom "name"
                                          :: Sexplib0.Sexp.Atom name
                                          :: _) ->
                                          Some name
                                      | _ -> None)
                                    module_fields
                              | _ -> [])
                            modules
                      | _ -> [])
                    lib_contents
                else []
            | sexp -> extract sexp)
          items
    | _ -> []
  in
  extract dune_describe

let get_test_modules dune_describe =
  let rec extract = function
    | Sexplib0.Sexp.List items ->
        List.concat_map
          (function
            | Sexplib0.Sexp.List
                (Sexplib0.Sexp.Atom kind :: Sexplib0.Sexp.List contents :: _)
              when kind = "test" || kind = "tests" || kind = "executable"
                   || kind = "executables" ->
                (* Extract test module names *)
                List.filter_map
                  (function
                    | Sexplib0.Sexp.List
                        (Sexplib0.Sexp.Atom "name"
                        :: Sexplib0.Sexp.Atom name
                        :: _)
                      when String.starts_with ~prefix:"test_" name ->
                        Some name
                    | _ -> None)
                  contents
            | sexp -> extract sexp)
          items
    | _ -> []
  in
  extract dune_describe
