(** Dune project structure analysis *)

let src = Logs.Src.create "merlint.dune" ~doc:"Dune interface"

module Log = (val Logs.src_log src : Logs.LOG)
open Sexplib0

(* Error helper function *)
let err_build_failed msg = Error (Fmt.str "Failed to build project: %s" msg)

type test_info = {
  name : string;
  files : Fpath.t list;
  libraries : string list; (* Library dependencies *)
}

type library_info = {
  name : string; (* Internal library name *)
  public_name : string option; (* Public library name *)
  files : Fpath.t list;
}

type describe = {
  libraries : library_info list;
  executables : (string * Fpath.t list) list;
  tests : test_info list;
}
(** Abstract type for dune describe results *)

(** Forward declaration for describe function *)
let describe_ref =
  ref (fun (project_root : Fpath.t) ->
      ignore project_root;
      { libraries = []; executables = []; tests = [] })

(** Ensure the project is built by running 'dune build' if needed *)
let ensure_project_built project_root =
  let dune_project = Fpath.(project_root / "dune-project") in
  if not (Sys.file_exists (Fpath.to_string dune_project)) then
    Ok () (* Not a dune project, skip build *)
  else
    let cmd =
      Fmt.str "dune build @check --root %s 2>/dev/null"
        (Filename.quote (Fpath.to_string project_root))
    in
    Log.info (fun m -> m "Ensuring project is built: %s" cmd);
    match Command.run cmd with
    | Ok _ -> Ok ()
    | Error msg -> err_build_failed msg

(** Check if a file is an executable *)
let is_executable dune_describe ml_file =
  let module_name = Fpath.(ml_file |> rem_ext |> basename) in
  List.exists
    (fun (name, files) ->
      ignore files;
      String.lowercase_ascii name = String.lowercase_ascii module_name)
    dune_describe.executables

(** Find all dune files in a directory tree *)
let rec dune_files dir =
  let dir_path = dir in
  let entries =
    try Sys.readdir (Fpath.to_string dir) with Sys_error _ -> [||]
  in
  Array.to_list entries
  |> List.concat_map (fun entry ->
         let path = Fpath.(dir_path / entry) in
         let path_str = Fpath.to_string path in
         if
           entry = "dune" && Sys.file_exists path_str
           && not (Sys.is_directory path_str)
         then [ path ]
         else if
           Sys.is_directory path_str && entry <> "_build" && entry <> ".git"
           && entry <> "_opam"
         then dune_files path
         else [])

(** Parse a dune file and extract module information *)
let parse_dune_file filename =
  try
    let ic = open_in (Fpath.to_string filename) in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;

    (* Parse all S-expressions in the file *)
    let stanzas =
      Parsexp.Many.parse_string content |> Result.value ~default:[]
    in
    Log.debug (fun m ->
        m "Parsed dune file %a: found %d stanzas" Fpath.pp filename
          (List.length stanzas));
    stanzas
  with Sys_error _ | End_of_file -> []

(** Extract modules from a modules field *)
let extract_modules_field = function
  | Sexp.List (Sexp.Atom "modules" :: modules) ->
      let result =
        List.filter_map
          (function Sexp.Atom name -> Some name | _ -> None)
          modules
      in
      Log.debug (fun m ->
          m "Extracted modules from field: %a"
            Fmt.(list ~sep:comma string)
            result);
      result
  | _ -> []

type project_item =
  | Library of {
      name : string;
      public_name : string option;
      dir : Fpath.t;
      modules : string list;
    }
  | Executable of { names : string list; dir : Fpath.t; modules : string list }
  | Test of {
      names : string list;
      dir : Fpath.t;
      modules : string list;
      libraries : string list;
    }
  | Cram_test of { dir : Fpath.t }

(** Check if a directory should be included based on dune directives *)
let should_include_dir dune_file =
  let stanzas = parse_dune_file dune_file in
  (* Check for data_only_dirs *)
  let has_data_only =
    List.exists
      (function
        | Sexp.List (Sexp.Atom "data_only_dirs" :: _) -> true | _ -> false)
      stanzas
  in
  not has_data_only

(** Extract project structure from dune stanza *)
let extract_project_item dir = function
  | Sexp.List (Sexp.Atom "library" :: fields) -> (
      let name =
        List.find_map
          (function
            | Sexp.List [ Sexp.Atom "name"; Sexp.Atom n ] -> Some n | _ -> None)
          fields
      in
      let public_name =
        List.find_map
          (function
            | Sexp.List [ Sexp.Atom "public_name"; Sexp.Atom n ] -> Some n
            | _ -> None)
          fields
      in
      let modules = List.concat_map extract_modules_field fields in
      match name with
      | Some n -> Some (Library { name = n; public_name; dir; modules })
      | None -> None)
  | Sexp.List (Sexp.Atom kind :: fields)
    when kind = "executable" || kind = "executables" ->
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
      let modules = List.concat_map extract_modules_field fields in
      if names <> [] then Some (Executable { names; dir; modules }) else None
  | Sexp.List (Sexp.Atom kind :: fields) when kind = "test" || kind = "tests" ->
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
      let modules = List.concat_map extract_modules_field fields in
      let libraries =
        List.concat_map
          (function
            | Sexp.List (Sexp.Atom "libraries" :: libs) ->
                List.filter_map
                  (function Sexp.Atom l -> Some l | _ -> None)
                  libs
            | _ -> [])
          fields
      in
      (* Handle test stanzas without explicit names - use "test" as default *)
      let test_names = if names = [] then [ "test" ] else names in
      Log.debug (fun m ->
          m "Found test stanza in %a: names=%a, modules=%a, libraries=%a"
            Fpath.pp dir
            Fmt.(list ~sep:comma string)
            test_names
            Fmt.(list ~sep:comma string)
            modules
            Fmt.(list ~sep:comma string)
            libraries);
      Some (Test { names = test_names; dir; modules; libraries })
  | Sexp.List (Sexp.Atom "cram" :: _) -> Some (Cram_test { dir })
  | _ -> None

(** Get source files for a project item *)
let item_files = function
  | Library { dir; modules; _ } ->
      let dir_path = dir in
      if modules = [] then (
        (* No explicit modules, find all .ml/.mli files in dir *)
        Log.debug (fun m ->
            m "Library in %a has no explicit modules, scanning directory"
              Fpath.pp dir);
        let files = ref [] in
        (try
           let entries = Sys.readdir (Fpath.to_string dir) in
           Array.iter
             (fun entry ->
               (* Skip temporary files (e.g., .#main.ml) *)
               if
                 (not
                    (String.length entry > 0
                    && entry.[0] = '.'
                    && String.contains entry '#'))
                 && (String.ends_with ~suffix:".ml" entry
                    || String.ends_with ~suffix:".mli" entry)
               then (
                 let file_path = Fpath.(dir_path / entry) |> Fpath.normalize in
                 Log.debug (fun m -> m "  Found file: %a" Fpath.pp file_path);
                 files := file_path :: !files))
             entries
         with Sys_error _ -> ());
        Log.debug (fun m ->
            m "Library in %a found %d files" Fpath.pp dir (List.length !files));
        !files)
      else (
        (* Explicit modules *)
        Log.debug (fun m ->
            m "Library in %a has explicit modules: %a" Fpath.pp dir
              Fmt.(list ~sep:comma string)
              modules);
        List.concat_map
          (fun m ->
            let ml = Fpath.(dir_path / (m ^ ".ml")) |> Fpath.normalize in
            let mli = Fpath.(dir_path / (m ^ ".mli")) |> Fpath.normalize in
            List.filter
              (fun p -> Sys.file_exists (Fpath.to_string p))
              [ ml; mli ])
          modules)
  | Executable { names; dir; modules } ->
      let dir_path = dir in
      let base_modules = if modules = [] then names else modules in
      List.concat_map
        (fun m ->
          let ml = Fpath.(dir_path / (m ^ ".ml")) |> Fpath.normalize in
          let mli = Fpath.(dir_path / (m ^ ".mli")) |> Fpath.normalize in
          List.filter (fun p -> Sys.file_exists (Fpath.to_string p)) [ ml; mli ])
        base_modules
  | Test { dir; modules; _ } ->
      let dir_path = dir in
      if modules = [] then (
        (* No explicit modules, find all .ml/.mli files in dir *)
        Log.debug (fun m ->
            m "Test in %a has no explicit modules, scanning directory" Fpath.pp
              dir);
        let files = ref [] in
        (try
           let entries = Sys.readdir (Fpath.to_string dir) in
           Array.iter
             (fun entry ->
               (* Skip temporary files (e.g., .#main.ml) *)
               if
                 (not
                    (String.length entry > 0
                    && entry.[0] = '.'
                    && String.contains entry '#'))
                 && (String.ends_with ~suffix:".ml" entry
                    || String.ends_with ~suffix:".mli" entry)
               then (
                 let file_path = Fpath.(dir_path / entry) |> Fpath.normalize in
                 Log.debug (fun m ->
                     m "  Found test file: %a" Fpath.pp file_path);
                 files := file_path :: !files))
             entries
         with Sys_error _ -> ());
        Log.debug (fun m ->
            m "Test in %a found %d files" Fpath.pp dir (List.length !files));
        !files)
      else (
        (* Explicit modules *)
        Log.debug (fun m ->
            m "Test in %a has explicit modules: %a" Fpath.pp dir
              Fmt.(list ~sep:comma string)
              modules);
        List.concat_map
          (fun m ->
            let ml = Fpath.(dir_path / (m ^ ".ml")) |> Fpath.normalize in
            let mli = Fpath.(dir_path / (m ^ ".mli")) |> Fpath.normalize in
            List.filter
              (fun p -> Sys.file_exists (Fpath.to_string p))
              [ ml; mli ])
          modules)
  | Cram_test _ -> []

(** Get all project source files from describe *)
let project_files dune_describe =
  (* Collect all files from libraries, executables, and tests *)
  let lib_files =
    List.concat_map
      (fun (lib_info : library_info) -> lib_info.files)
      dune_describe.libraries
  in
  let exec_files = List.concat_map snd dune_describe.executables in
  let test_files =
    List.concat_map (fun (t : test_info) -> t.files) dune_describe.tests
  in

  Log.debug (fun m -> m "Libraries contribute %d files" (List.length lib_files));
  Log.debug (fun m ->
      m "Executables contribute %d files" (List.length exec_files));
  Log.debug (fun m -> m "Tests contribute %d files" (List.length test_files));

  (* Combine and deduplicate *)
  let all_files =
    lib_files @ exec_files @ test_files |> List.sort_uniq Fpath.compare
  in
  Log.debug (fun m -> m "Total unique files: %d" (List.length all_files));
  all_files

(** Get executable modules from describe *)
let executable_modules dune_describe =
  dune_describe.executables |> List.concat_map snd
  |> List.filter_map (fun file ->
         let file_str = Fpath.to_string file in
         if String.ends_with ~suffix:".ml" file_str then
           Some (String.capitalize_ascii Fpath.(file |> rem_ext |> basename))
         else None)
  |> List.sort_uniq String.compare

(** Get library modules from describe *)
let lib_modules dune_describe =
  dune_describe.libraries
  |> List.concat_map (fun (lib_info : library_info) -> lib_info.files)
  |> List.filter_map (fun file ->
         let file_str = Fpath.to_string file in
         if String.ends_with ~suffix:".ml" file_str then
           Some Fpath.(file |> rem_ext |> basename)
         else None)
  |> List.sort_uniq String.compare

(** Get test modules from describe *)
let test_modules dune_describe =
  dune_describe.tests
  |> List.concat_map (fun (t : test_info) -> t.files)
  |> List.filter_map (fun file ->
         let file_str = Fpath.to_string file in
         if String.ends_with ~suffix:".ml" file_str then
           Some Fpath.(file |> rem_ext |> basename)
         else None)
  |> List.sort_uniq String.compare

(** Get project structure from dune files *)
let project_structure project_root =
  (* Find all dune files *)
  let dune_files = dune_files project_root in
  Log.debug (fun m ->
      m "Found %d dune files in %a" (List.length dune_files) Fpath.pp
        project_root);
  List.iter
    (fun f -> Log.debug (fun m -> m "  Dune file: %a" Fpath.pp f))
    dune_files;

  (* First pass: find all cram directories *)
  let cram_dirs =
    List.fold_left
      (fun acc dune_file ->
        let dir = Fpath.(dune_file |> parent |> normalize) in
        let stanzas = parse_dune_file dune_file in
        if
          List.exists
            (function Sexp.List (Sexp.Atom "cram" :: _) -> true | _ -> false)
            stanzas
        then (
          Log.debug (fun m ->
              m "Found cram directory: %s" (Fpath.to_string dir));
          dir :: acc)
        else acc)
      [] dune_files
  in
  Log.debug (fun m ->
      m "Total cram directories found: %d" (List.length cram_dirs));
  List.iter
    (fun dir -> Log.debug (fun m -> m "Cram dir: %s" (Fpath.to_string dir)))
    cram_dirs;

  (* Helper to check if a directory is under a cram directory *)
  let is_under_cram_dir path =
    let path_fp = path |> Fpath.normalize in
    let result =
      List.exists
        (fun cram_dir ->
          let cram_fp = cram_dir |> Fpath.normalize in
          Fpath.is_prefix cram_fp path_fp)
        cram_dirs
    in
    if result then
      Log.debug (fun m ->
          m "Path %s is under cram directory" (Fpath.to_string path_fp));
    result
  in

  (* Extract project structure, excluding anything under cram directories *)
  let project_items =
    List.concat_map
      (fun dune_file ->
        if should_include_dir dune_file then
          let dir = Fpath.(dune_file |> parent |> normalize) in
          if not (is_under_cram_dir dir) then
            let stanzas = parse_dune_file dune_file in
            List.filter_map (extract_project_item dir) stanzas
          else (
            Log.debug (fun m ->
                m "Skipping dune file in cram dir: %s (dir=%s)"
                  (Fpath.to_string dune_file)
                  (Fpath.to_string dir));
            [])
        else [])
      dune_files
  in
  Log.debug (fun m ->
      m "Found %d project items after filtering cram dirs"
        (List.length project_items));
  project_items

(** Real describe implementation *)
let describe_impl project_root =
  let structure = project_structure project_root in
  let libraries =
    structure
    |> List.filter_map (function
         | Library { name; public_name; dir; modules } ->
             let files =
               item_files (Library { name; public_name; dir; modules })
             in
             Some ({ name; public_name; files } : library_info)
         | _ -> None)
  in
  let executables =
    structure
    |> List.filter_map (function
         | Executable { names; dir; modules } -> (
             let files = item_files (Executable { names; dir; modules }) in
             match names with [] -> None | main :: _ -> Some (main, files))
         | _ -> None)
  in
  let tests =
    structure
    |> List.filter_map (function
         | Test { names; dir; modules; libraries } -> (
             let files = item_files (Test { names; dir; modules; libraries }) in
             match names with
             | [] -> None
             | main :: _ -> Some { name = main; files; libraries })
         | _ -> None)
  in
  { libraries; executables; tests }

(* Initialize the describe function *)
let () = describe_ref := describe_impl

(* Public describe function that dereferences *)
let describe project_root = !describe_ref project_root

(** Merge multiple describe values *)
let merge describes =
  Log.debug (fun m -> m "Merging %d describes" (List.length describes));

  (* Concatenate all entries without merging - entries from different directories
     should remain separate even if they have the same name *)
  let libraries = describes |> List.concat_map (fun d -> d.libraries) in
  let executables = describes |> List.concat_map (fun d -> d.executables) in
  let tests = describes |> List.concat_map (fun d -> d.tests) in

  Log.debug (fun m ->
      m "Merged describes: %d libraries, %d executables, %d tests"
        (List.length libraries) (List.length executables) (List.length tests));

  { libraries; executables; tests }

(** Filter out files matching patterns *)
let exclude patterns describe =
  let filter_files files =
    List.filter
      (fun file ->
        let file_str = Fpath.to_string file in
        not
          (List.exists
             (fun pattern ->
               (* Check if pattern is a substring of file *)
               let rec contains s1 s2 =
                 String.length s1 >= String.length s2
                 && (String.sub s1 0 (String.length s2) = s2
                    || contains (String.sub s1 1 (String.length s1 - 1)) s2)
               in
               contains file_str pattern)
             patterns))
      files
  in
  let libraries =
    List.map
      (fun (lib_info : library_info) ->
        { lib_info with files = filter_files lib_info.files })
      describe.libraries
  in
  let executables =
    List.map
      (fun (name, files) -> (name, filter_files files))
      describe.executables
  in
  let tests =
    List.map
      (fun (t : test_info) -> { t with files = filter_files t.files })
      describe.tests
  in
  { libraries; executables; tests }

(** Create a synthetic describe for individual files *)
let synthetic files =
  let fpath_files = List.map Fpath.v files in
  (* Separate test files from library files based on module name *)
  let lib_files, test_files =
    List.partition
      (fun f ->
        let basename = Fpath.(f |> rem_ext |> basename) in
        not (String.starts_with ~prefix:"test_" basename || basename = "test"))
      fpath_files
  in
  {
    libraries =
      (if lib_files = [] then []
       else
         [
           ({
              name = "merlint_synthetic";
              public_name = None;
              files = lib_files;
            }
             : library_info);
         ]);
    executables = [];
    tests =
      (if test_files = [] then []
       else [ { name = "test"; files = test_files; libraries = [] } ]);
  }

(** Get libraries from describe *)
let libraries describe = describe.libraries

(** Get tests from describe *)
let tests describe = describe.tests
