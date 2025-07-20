(** Dune project structure analysis *)

let src = Logs.Src.create "merlint.dune" ~doc:"Dune interface"

module Log = (val Logs.src_log src : Logs.LOG)
open Sexplib0

type describe = {
  libraries : (string * string list) list;
  executables : (string * string list) list;
  tests : (string * string list) list;
}
(** Abstract type for dune describe results *)

(** Forward declaration for describe function *)
let describe_ref =
  ref (fun _project_root -> { libraries = []; executables = []; tests = [] })

(** Ensure the project is built by running 'dune build' if needed *)
let ensure_project_built project_root =
  let dune_project = Filename.concat project_root "dune-project" in
  if not (Sys.file_exists dune_project) then
    Ok () (* Not a dune project, skip build *)
  else
    let cmd =
      Fmt.str "dune build @check --root %s" (Filename.quote project_root)
    in
    Log.info (fun m -> m "Ensuring project is built: %s" cmd);
    match Command.run cmd with
    | Ok _ -> Ok ()
    | Error msg -> Error (Fmt.str "Failed to build project: %s" msg)

(** Check if a file is an executable *)
let is_executable dune_describe ml_file =
  let module_name = Filename.basename (Filename.remove_extension ml_file) in
  List.exists
    (fun (name, _files) ->
      String.lowercase_ascii name = String.lowercase_ascii module_name)
    dune_describe.executables

(** Find all dune files in a directory tree *)
let rec find_dune_files dir =
  let dir_path = Fpath.v dir in
  let entries = try Sys.readdir dir with Sys_error _ -> [||] in
  Array.to_list entries
  |> List.concat_map (fun entry ->
         let path = Fpath.(dir_path / entry) in
         let path_str = Fpath.to_string path in
         if
           entry = "dune" && Sys.file_exists path_str
           && not (Sys.is_directory path_str)
         then [ path_str ]
         else if
           Sys.is_directory path_str && entry <> "_build" && entry <> ".git"
           && entry <> "_opam"
         then find_dune_files path_str
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

type project_item =
  | Library of { name : string; dir : string; modules : string list }
  | Executable of { names : string list; dir : string; modules : string list }
  | Test of { names : string list; dir : string; modules : string list }
  | CramTest of { dir : string }

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
            | Sexp.List [ Sexp.Atom "name"; Sexp.Atom n ] -> Some n
            | Sexp.List [ Sexp.Atom "public_name"; Sexp.Atom n ] -> Some n
            | _ -> None)
          fields
      in
      let modules = List.concat_map extract_modules_field fields in
      match name with
      | Some n -> Some (Library { name = n; dir; modules })
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
      if names <> [] then Some (Test { names; dir; modules }) else None
  | Sexp.List (Sexp.Atom "cram" :: _) -> Some (CramTest { dir })
  | _ -> None

(** Get source files for a project item *)
let get_item_files = function
  | Library { dir; modules; _ } ->
      let dir_path = Fpath.v dir in
      if modules = [] then (
        (* No explicit modules, find all .ml/.mli files in dir *)
        let files = ref [] in
        (try
           let entries = Sys.readdir dir in
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
               then
                 let file_path =
                   Fpath.(dir_path / entry)
                   |> Fpath.normalize |> Fpath.to_string
                 in
                 files := file_path :: !files)
             entries
         with _ -> ());
        !files)
      else
        (* Explicit modules *)
        List.concat_map
          (fun m ->
            let ml =
              Fpath.(dir_path / (m ^ ".ml"))
              |> Fpath.normalize |> Fpath.to_string
            in
            let mli =
              Fpath.(dir_path / (m ^ ".mli"))
              |> Fpath.normalize |> Fpath.to_string
            in
            List.filter Sys.file_exists [ ml; mli ])
          modules
  | Executable { names; dir; modules } ->
      let dir_path = Fpath.v dir in
      let base_modules = if modules = [] then names else modules in
      List.concat_map
        (fun m ->
          let ml =
            Fpath.(dir_path / (m ^ ".ml")) |> Fpath.normalize |> Fpath.to_string
          in
          let mli =
            Fpath.(dir_path / (m ^ ".mli"))
            |> Fpath.normalize |> Fpath.to_string
          in
          List.filter Sys.file_exists [ ml; mli ])
        base_modules
  | Test { dir; modules; _ } ->
      let dir_path = Fpath.v dir in
      if modules = [] then (
        (* No explicit modules, find all .ml/.mli files in dir *)
        let files = ref [] in
        (try
           let entries = Sys.readdir dir in
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
               then
                 let file_path =
                   Fpath.(dir_path / entry)
                   |> Fpath.normalize |> Fpath.to_string
                 in
                 files := file_path :: !files)
             entries
         with _ -> ());
        !files)
      else
        (* Explicit modules *)
        List.concat_map
          (fun m ->
            let ml =
              Fpath.(dir_path / (m ^ ".ml"))
              |> Fpath.normalize |> Fpath.to_string
            in
            let mli =
              Fpath.(dir_path / (m ^ ".mli"))
              |> Fpath.normalize |> Fpath.to_string
            in
            List.filter Sys.file_exists [ ml; mli ])
          modules
  | CramTest _ -> []

(** Get all project source files from describe *)
let get_project_files dune_describe =
  (* Collect all files from libraries, executables, and tests *)
  let lib_files = List.concat_map snd dune_describe.libraries in
  let exec_files = List.concat_map snd dune_describe.executables in
  let test_files = List.concat_map snd dune_describe.tests in

  Log.debug (fun m -> m "Libraries contribute %d files" (List.length lib_files));
  Log.debug (fun m ->
      m "Executables contribute %d files" (List.length exec_files));
  Log.debug (fun m -> m "Tests contribute %d files" (List.length test_files));

  (* Combine and deduplicate *)
  let all_files =
    lib_files @ exec_files @ test_files |> List.sort_uniq String.compare
  in
  Log.debug (fun m -> m "Total unique files: %d" (List.length all_files));
  all_files

(** Get library modules from describe *)
let get_lib_modules dune_describe =
  dune_describe.libraries |> List.concat_map snd
  |> List.filter_map (fun file ->
         if String.ends_with ~suffix:".ml" file then
           Some (Filename.basename file |> Filename.remove_extension)
         else None)
  |> List.sort_uniq String.compare

(** Get test modules from describe *)
let get_test_modules dune_describe =
  dune_describe.tests |> List.concat_map snd
  |> List.filter_map (fun file ->
         if String.ends_with ~suffix:".ml" file then
           Some (Filename.basename file |> Filename.remove_extension)
         else None)
  |> List.sort_uniq String.compare

(** Get project structure from dune files *)
let get_project_structure project_root =
  (* Find all dune files *)
  let dune_files = find_dune_files project_root in

  (* First pass: find all cram directories *)
  let cram_dirs =
    List.fold_left
      (fun acc dune_file ->
        let dir = Fpath.(v dune_file |> parent |> normalize |> to_string) in
        let stanzas = parse_dune_file dune_file in
        if
          List.exists
            (function Sexp.List (Sexp.Atom "cram" :: _) -> true | _ -> false)
            stanzas
        then (
          Log.debug (fun m -> m "Found cram directory: %s" dir);
          dir :: acc)
        else acc)
      [] dune_files
  in
  Log.debug (fun m ->
      m "Total cram directories found: %d" (List.length cram_dirs));

  (* Helper to check if a directory is under a cram directory *)
  let is_under_cram_dir path =
    let norm_path = Fpath.(v path |> normalize |> to_string) in
    List.exists
      (fun cram_dir ->
        String.starts_with ~prefix:(cram_dir ^ "/") norm_path
        || norm_path = cram_dir)
      cram_dirs
  in

  (* Extract project structure, excluding anything under cram directories *)
  let project_items =
    List.concat_map
      (fun dune_file ->
        if should_include_dir dune_file then
          let dir = Fpath.(v dune_file |> parent |> normalize |> to_string) in
          if not (is_under_cram_dir dir) then
            let stanzas = parse_dune_file dune_file in
            List.filter_map (extract_project_item dir) stanzas
          else (
            Log.debug (fun m ->
                m "Skipping dune file in cram dir: %s" dune_file);
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
  let structure = get_project_structure project_root in
  let libraries =
    structure
    |> List.filter_map (function
         | Library { name; dir; modules } ->
             let files = get_item_files (Library { name; dir; modules }) in
             Some (name, files)
         | _ -> None)
  in
  let executables =
    structure
    |> List.filter_map (function
         | Executable { names; dir; modules } -> (
             let files = get_item_files (Executable { names; dir; modules }) in
             match names with [] -> None | main :: _ -> Some (main, files))
         | _ -> None)
  in
  let tests =
    structure
    |> List.filter_map (function
         | Test { names; dir; modules } -> (
             let files = get_item_files (Test { names; dir; modules }) in
             match names with [] -> None | main :: _ -> Some (main, files))
         | _ -> None)
  in
  { libraries; executables; tests }

(* Initialize the describe function *)
let () = describe_ref := describe_impl

(* Public describe function that dereferences *)
let describe project_root = !describe_ref project_root

(** Get all libraries in the project *)
let libraries project_root =
  let desc = describe project_root in
  desc.libraries

(** Get all executables in the project *)
let executables project_root =
  let desc = describe project_root in
  desc.executables

(** Get all tests in the project *)
let tests project_root =
  let desc = describe project_root in
  desc.tests

(** Merge multiple describe values *)
let merge describes =
  let libraries =
    describes
    |> List.concat_map (fun d -> d.libraries)
    |> List.sort_uniq (fun (n1, _) (n2, _) -> String.compare n1 n2)
  in
  let executables =
    describes
    |> List.concat_map (fun d -> d.executables)
    |> List.sort_uniq (fun (n1, _) (n2, _) -> String.compare n1 n2)
  in
  let tests =
    describes
    |> List.concat_map (fun d -> d.tests)
    |> List.sort_uniq (fun (n1, _) (n2, _) -> String.compare n1 n2)
  in
  { libraries; executables; tests }

(** Filter out files matching patterns *)
let exclude patterns describe =
  let filter_files files =
    List.filter
      (fun file ->
        not
          (List.exists
             (fun pattern ->
               (* Check if pattern is a substring of file *)
               let rec contains s1 s2 =
                 String.length s1 >= String.length s2
                 && (String.sub s1 0 (String.length s2) = s2
                    || contains (String.sub s1 1 (String.length s1 - 1)) s2)
               in
               contains file pattern)
             patterns))
      files
  in
  let libraries =
    List.map
      (fun (name, files) -> (name, filter_files files))
      describe.libraries
  in
  let executables =
    List.map
      (fun (name, files) -> (name, filter_files files))
      describe.executables
  in
  let tests =
    List.map (fun (name, files) -> (name, filter_files files)) describe.tests
  in
  { libraries; executables; tests }

(** Create a synthetic describe for individual files *)
let create_synthetic files =
  { libraries = []; executables = [ ("merlint_synthetic", files) ]; tests = [] }
