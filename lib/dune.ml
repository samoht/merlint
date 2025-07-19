(** Wrapper for dune commands *)

let src = Logs.Src.create "merlint.dune" ~doc:"Dune interface"

module Log = (val Logs.src_log src : Logs.LOG)
open Sexplib0

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

(** Find all dune files in a directory tree *)
let rec find_dune_files dir =
  let entries = try Sys.readdir dir with Sys_error _ -> [||] in
  Array.to_list entries
  |> List.concat_map (fun entry ->
         let path = Filename.concat dir entry in
         if
           entry = "dune" && Sys.file_exists path && not (Sys.is_directory path)
         then [ path ]
         else if
           Sys.is_directory path && entry <> "_build" && entry <> ".git"
           && entry <> "_opam"
         then find_dune_files path
         else [])

(** Parse a dune file and extract module information *)
let parse_dune_file filename =
  try
    let ic = open_in filename in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;

    (* Parse all S-expressions in the file *)
    Parsexp.Many.parse_string content |> Result.value ~default:[]
  with _ -> []

(** Extract modules from a modules field *)
let extract_modules_field = function
  | Sexp.List (Sexp.Atom "modules" :: modules) ->
      List.filter_map
        (function Sexp.Atom name -> Some name | _ -> None)
        modules
  | _ -> []

(** Extract library modules from a stanza *)
let _extract_library_info = function
  | Sexp.List (Sexp.Atom "library" :: fields) ->
      let modules = List.concat_map extract_modules_field fields in
      let name =
        List.find_map
          (function
            | Sexp.List [ Sexp.Atom "name"; Sexp.Atom n ] -> Some n | _ -> None)
          fields
      in
      (name, modules)
  | _ -> (None, [])

(** Extract test info from a stanza *)
let extract_test_info = function
  | Sexp.List (Sexp.Atom "test" :: fields) ->
      let name =
        List.find_map
          (function
            | Sexp.List [ Sexp.Atom "name"; Sexp.Atom n ] -> Some n | _ -> None)
          fields
      in
      let modules =
        match List.concat_map extract_modules_field fields with
        | [] -> ( match name with Some n -> [ n ] | None -> [])
        | mods -> mods
      in
      Some modules
  | Sexp.List (Sexp.Atom "tests" :: fields) ->
      let names =
        List.find_map
          (function
            | Sexp.List (Sexp.Atom "names" :: names) ->
                Some
                  (List.filter_map
                     (function Sexp.Atom n -> Some n | _ -> None)
                     names)
            | _ -> None)
          fields
      in
      names
  | _ -> None

(** Get test modules from all dune files in project *)
let _get_test_modules project_root =
  find_dune_files project_root
  |> List.concat_map (fun dune_file ->
         let dir = Filename.dirname dune_file in
         let sexps = parse_dune_file dune_file in
         sexps
         |> List.concat_map (fun sexp ->
                match extract_test_info sexp with
                | Some modules ->
                    List.map (fun m -> Filename.concat dir m) modules
                | None -> []))

(** Extract all source files from dune describe output *)
let extract_source_files sexp =
  let rec extract_modules = function
    | Sexplib0.Sexp.List
        (Sexplib0.Sexp.Atom "modules" :: [ Sexplib0.Sexp.List modules ]) ->
        (* Found modules section *)
        Log.debug (fun m ->
            m "Found modules section with %d entries" (List.length modules));
        List.concat_map
          (function
            | Sexplib0.Sexp.List
                [
                  Sexplib0.Sexp.Atom "impl";
                  Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom path ];
                ] ->
                (* impl entry with path in a list *)
                let source_path =
                  if String.starts_with ~prefix:"_build/default/" path then
                    String.sub path 15 (String.length path - 15)
                  else path
                in
                [ source_path ]
            | Sexplib0.Sexp.List
                [ Sexplib0.Sexp.Atom "impl"; Sexplib0.Sexp.Atom path ] ->
                (* impl entry with path directly *)
                let source_path =
                  if String.starts_with ~prefix:"_build/default/" path then
                    String.sub path 15 (String.length path - 15)
                  else path
                in
                [ source_path ]
            | Sexplib0.Sexp.List
                [
                  Sexplib0.Sexp.Atom "intf";
                  Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom path ];
                ] ->
                (* intf entry with path in a list *)
                let source_path =
                  if String.starts_with ~prefix:"_build/default/" path then
                    String.sub path 15 (String.length path - 15)
                  else path
                in
                [ source_path ]
            | Sexplib0.Sexp.List
                [ Sexplib0.Sexp.Atom "intf"; Sexplib0.Sexp.Atom path ] ->
                (* intf entry with path directly *)
                let source_path =
                  if String.starts_with ~prefix:"_build/default/" path then
                    String.sub path 15 (String.length path - 15)
                  else path
                in
                [ source_path ]
            | Sexplib0.Sexp.List items ->
                (* Module with nested fields *)
                List.concat_map
                  (function
                    | Sexplib0.Sexp.List
                        (Sexplib0.Sexp.Atom "impl"
                        :: Sexplib0.Sexp.Atom path
                        :: _) ->
                        (* Convert build path to source path *)
                        let source_path =
                          if String.starts_with ~prefix:"_build/default/" path
                          then String.sub path 15 (String.length path - 15)
                          else path
                        in
                        [ source_path ]
                    | Sexplib0.Sexp.List
                        (Sexplib0.Sexp.Atom "intf"
                        :: Sexplib0.Sexp.Atom path
                        :: _) ->
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

  let rec extract_from_stanzas sexp =
    match sexp with
    | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "library" :: rest) -> (
        (* Direct library stanza *)
        match rest with
        | [ Sexplib0.Sexp.List lib_contents ] ->
            (* Library stanza has nested list structure *)
            let is_local =
              List.exists
                (function
                  | Sexplib0.Sexp.List
                      [ Sexplib0.Sexp.Atom "local"; Sexplib0.Sexp.Atom "true" ]
                    ->
                      true
                  | _ -> false)
                lib_contents
            in
            if is_local then (
              Log.debug (fun m -> m "Found local library, extracting modules");
              let modules = List.concat_map extract_modules lib_contents in
              Log.debug (fun m ->
                  m "Extracted %d files from library" (List.length modules));
              modules)
            else (
              Log.debug (fun m -> m "Library is not local, skipping");
              [])
        | _ -> [])
    | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "executables" :: exec_contents) ->
        List.concat_map extract_modules exec_contents
    | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "executable" :: exec_contents) ->
        List.concat_map extract_modules exec_contents
    | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "test" :: test_contents) ->
        List.concat_map extract_modules test_contents
    | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "tests" :: test_contents) ->
        List.concat_map extract_modules test_contents
    | Sexplib0.Sexp.List items ->
        (* List of stanzas *)
        List.concat_map extract_from_stanzas items
    | _ -> []
  in

  Log.debug (fun m ->
      m "extract_source_files input: %s" (Sexplib0.Sexp.to_string_hum sexp));
  let result = extract_from_stanzas sexp in
  Log.debug (fun m ->
      m "extract_source_files result: [%s]" (String.concat "; " result));
  result

(** Check if a dune stanza is a cram test *)
let is_cram_stanza = function
  | Sexp.List (Sexp.Atom "cram" :: _) -> true
  | _ -> false

(** Extract all source files mentioned in a dune stanza *)
let extract_source_files_from_stanza dir = function
  | Sexp.List (Sexp.Atom kind :: fields)
    when kind = "library" || kind = "executable" || kind = "executables"
         || kind = "test" || kind = "tests" ->
      (* Look for modules field *)
      let modules = List.concat_map extract_modules_field fields in
      (* Look for name/names for executables/tests *)
      let names =
        List.concat_map
          (function
            | Sexp.List [ Sexp.Atom "name"; Sexp.Atom n ] -> [ n ]
            | Sexp.List (Sexp.Atom "names" :: names) ->
                List.filter_map
                  (function Sexp.Atom n -> Some n | _ -> None)
                  names
            | _ -> [])
          fields
      in
      let base_modules = if modules = [] then names else modules in
      (* Generate .ml and .mli paths *)
      List.concat_map
        (fun m ->
          let ml_path = Filename.concat dir (m ^ ".ml") in
          let mli_path = Filename.concat dir (m ^ ".mli") in
          List.filter Sys.file_exists [ ml_path; mli_path ])
        base_modules
  | _ -> []

(** Find all OCaml source files by parsing dune files and using find as fallback
*)
let find_ocaml_files project_root =
  (* First, find all dune files and identify cram directories *)
  let dune_files = find_dune_files project_root in
  Log.debug (fun m -> m "Found %d dune files" (List.length dune_files));

  (* Identify directories containing cram tests *)
  let cram_dirs =
    List.filter_map
      (fun dune_file ->
        let stanzas = parse_dune_file dune_file in
        if List.exists is_cram_stanza stanzas then
          Some (Filename.dirname dune_file)
        else None)
      dune_files
  in
  Log.debug (fun m ->
      m "Found %d cram test directories" (List.length cram_dirs));
  List.iter
    (fun dir -> Log.debug (fun m -> m "  Cram directory: %s" dir))
    cram_dirs;

  let files_from_dune =
    List.concat_map
      (fun dune_file ->
        let dir = Filename.dirname dune_file in
        let stanzas = parse_dune_file dune_file in
        (* Skip if this directory has cram tests *)
        if List.exists is_cram_stanza stanzas then []
        else List.concat_map (extract_source_files_from_stanza dir) stanzas)
      dune_files
  in

  (* Also use find to catch any files not in dune files *)
  let cmd =
    Fmt.str
      "find %s -type f \\( -name '*.ml' -o -name '*.mli' \\) | grep -v \
       '_build' | grep -v '_opam' | grep -v '.#'"
      (Filename.quote project_root)
  in
  let files_from_find =
    match Command.run cmd with
    | Ok output ->
        String.split_on_char '\n' output
        |> List.filter (fun s -> String.length s > 0)
        |> List.filter_map (fun path_str ->
               match Fpath.of_string path_str with
               | Error _ -> None
               | Ok path -> (
                   (* Convert to relative path if needed *)
                   match Fpath.of_string project_root with
                   | Error _ -> Some (Fpath.to_string path)
                   | Ok root -> (
                       match Fpath.relativize ~root path with
                       | Some rel -> Some (Fpath.to_string rel)
                       | None -> Some (Fpath.to_string path))))
        |> List.filter (fun path_str ->
               (* Exclude files in cram directories *)
               not (List.exists (fun cram_dir ->
                 (* Simple string prefix check for directories *)
                 let cram_prefix = 
                   if String.ends_with ~suffix:"/" cram_dir then cram_dir
                   else cram_dir ^ "/"
                 in
                 String.starts_with ~prefix:cram_prefix path_str
               ) cram_dirs))
    | Error err ->
        Log.err (fun m -> m "Failed to run find command: %s" err);
        []
  in

  (* Combine and deduplicate *)
  let all_files =
    List.sort_uniq String.compare (files_from_dune @ files_from_find)
  in
  Log.debug (fun m ->
      m "Found %d files from dune files, %d from find, %d total unique"
        (List.length files_from_dune)
        (List.length files_from_find)
        (List.length all_files));
  all_files

(** Get all project source files using dune describe *)
let get_project_files dune_describe =
  try
    let files = extract_source_files dune_describe in
    (* Remove duplicates and sort *)
    let unique_files = List.sort_uniq String.compare files in
    Log.debug (fun m ->
        m "Found %d source files from dune describe" (List.length unique_files));
    if List.length unique_files = 0 then (
      Log.info (fun m ->
          m "No files found from dune describe, falling back to find command");
      find_ocaml_files ".")
    else unique_files
  with exn ->
    Log.err (fun m ->
        m "Failed to extract source files: %s" (Printexc.to_string exn));
    Log.info (fun m -> m "Falling back to find command");
    find_ocaml_files "."

let get_lib_modules dune_describe =
  let rec extract = function
    | Sexplib0.Sexp.List items ->
        List.concat_map
          (function
            | Sexplib0.Sexp.List
                [
                  Sexplib0.Sexp.Atom "library"; Sexplib0.Sexp.List lib_contents;
                ] ->
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
                          (Sexplib0.Sexp.Atom "modules"
                          :: [ Sexplib0.Sexp.List modules ]) ->
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
