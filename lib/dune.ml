(** Dune project structure analysis *)

let src = Logs.Src.create "merlint.dune" ~doc:"Dune interface"

module Log = (val Logs.src_log src : Logs.LOG)

(* Error helper function *)
let err_build_failed msg =
  Fmt.kstr (fun s -> Error s) "Failed to build project: %s" msg

type test_info = {
  name : string;
  files : Fpath.t list;
  libraries : string list; (* Library dependencies *)
}

type library_info = {
  name : string; (* Internal library name *)
  public_name : string option; (* Public library name *)
  files : Fpath.t list;
  private_modules : string list;
      (* Module names listed in (private_modules ...) *)
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
let ensure_project_built ~path mgr =
  let suppress_stderr =
    match Logs.Src.level src with
    | Some Logs.Debug -> "" (* show stderr in -vv mode *)
    | _ -> " 2>/dev/null"
  in
  (* Use @check to produce .cmt files for all modules (including wrapped
     executables/tests where plain 'dune build' only produces native code). *)
  let cmd = Fmt.str "dune build @check %s%s" path suppress_stderr in
  (* Print command when verbose *)
  (match Logs.level () with
  | Some (Logs.Info | Logs.Debug) ->
      Fmt.epr "Running: %s@.    cwd: %s@." cmd (Sys.getcwd ())
  | _ -> ());
  match Command.run mgr cmd with
  | Ok _ -> Ok ()
  | Error msg -> err_build_failed msg

(** Check if a file belongs to an executable stanza *)
let is_executable dune_describe ml_file =
  let module_name = Fpath.(ml_file |> rem_ext |> basename) in
  let ml_file_lc = String.lowercase_ascii (Fpath.to_string ml_file) in
  List.exists
    (fun (name, files) ->
      (* Check if this is the main executable module *)
      String.lowercase_ascii name = String.lowercase_ascii module_name
      (* Or if this file appears in the executable's file list *)
      || List.exists
           (fun f -> String.lowercase_ascii (Fpath.to_string f) = ml_file_lc)
           files)
    dune_describe.executables

(** Find all dune files in a directory tree *)
let rec files dir =
  let dir_path = dir in
  let entries =
    try Sys.readdir (Fpath.to_string dir) with Sys_error _ -> [||]
  in
  Array.to_list entries
  |> List.concat_map (fun entry ->
      let path = Fpath.(dir_path / entry) in
      let path_str = Fpath.to_string path in
      let first_char = if String.length entry > 0 then entry.[0] else '\000' in
      if first_char = '.' || first_char = '_' then []
      else if
        entry = "dune" && Sys.file_exists path_str
        && not (try Sys.is_directory path_str with Sys_error _ -> true)
      then [ path ]
      else if try Sys.is_directory path_str with Sys_error _ -> false then
        files path
      else [])

(** Parse a dune file and extract module information *)
let parse_dune_file filename =
  try
    let ic = open_in (Fpath.to_string filename) in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;

    (* Parse all S-expressions in the file *)
    let stanzas =
      match Sexp.Value.parse_string_many content with
      | Ok s -> s
      | Error e -> raise (Sexp.Error e)
    in
    Log.debug (fun m ->
        m "Parsed dune file %a: found %d stanzas" Fpath.pp filename
          (List.length stanzas));
    stanzas
  with Sys_error _ | End_of_file | Sexp.Error _ -> []

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

(** Extract module names from a (private_modules ...) field *)
let extract_private_modules_field = function
  | Sexp.List (Sexp.Atom "private_modules" :: modules) ->
      List.filter_map
        (function Sexp.Atom name -> Some name | _ -> None)
        modules
  | _ -> []

type project_item =
  | Library of {
      name : string;
      public_name : string option;
      dir : Fpath.t;
      modules : string list;
      private_modules : string list;
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

let extract_test_item dir fields =
  let names =
    List.concat_map
      (function
        | Sexp.List [ Sexp.Atom "name"; Sexp.Atom n ] -> [ n ]
        | Sexp.List (Sexp.Atom "names" :: names) ->
            List.filter_map (function Sexp.Atom n -> Some n | _ -> None) names
        | _ -> [])
      fields
  in
  let modules = List.concat_map extract_modules_field fields in
  let libraries =
    List.concat_map
      (function
        | Sexp.List (Sexp.Atom "libraries" :: libs) ->
            List.filter_map (function Sexp.Atom l -> Some l | _ -> None) libs
        | _ -> [])
      fields
  in
  (* Handle test stanzas without explicit names - use "test" as default *)
  let test_names = if names = [] then [ "test" ] else names in
  Log.debug (fun m ->
      m "Found test stanza in %a: names=%a, modules=%a, libraries=%a" Fpath.pp
        dir
        Fmt.(list ~sep:comma string)
        test_names
        Fmt.(list ~sep:comma string)
        modules
        Fmt.(list ~sep:comma string)
        libraries);
  Some (Test { names = test_names; dir; modules; libraries })

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
      let private_modules =
        List.concat_map extract_private_modules_field fields
      in
      match name with
      | Some n ->
          Some
            (Library { name = n; public_name; dir; modules; private_modules })
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
      extract_test_item dir fields
  | Sexp.List (Sexp.Atom "cram" :: _) -> Some (Cram_test { dir })
  | _ -> None

(** Get source files for a project item *)
let is_ocaml_source_file entry =
  (* Skip temporary files (e.g., .#main.ml) *)
  (not
     (String.length entry > 0 && entry.[0] = '.' && String.contains entry '#'))
  && (String.ends_with ~suffix:".ml" entry
     || String.ends_with ~suffix:".mli" entry)

let scan_directory_for_ml_files item_type dir =
  Log.debug (fun m ->
      m "%s in %a has no explicit modules, scanning directory" item_type
        Fpath.pp dir);
  let files = ref [] in
  (try
     let entries = Sys.readdir (Fpath.to_string dir) in
     Array.iter
       (fun entry ->
         if is_ocaml_source_file entry then (
           let file_path = Fpath.(dir / entry) |> Fpath.normalize in
           Log.debug (fun m ->
               m "  Found %s file: %a" item_type Fpath.pp file_path);
           files := file_path :: !files))
       entries
   with Sys_error _ -> ());
  Log.debug (fun m ->
      m "%s in %a found %d files" item_type Fpath.pp dir (List.length !files));
  !files

let files_of_modules dir modules =
  List.concat_map
    (fun m ->
      let ml = Fpath.(dir / (m ^ ".ml")) |> Fpath.normalize in
      let mli = Fpath.(dir / (m ^ ".mli")) |> Fpath.normalize in
      List.filter (fun p -> Sys.file_exists (Fpath.to_string p)) [ ml; mli ])
    modules

let item_files = function
  | Library { dir; modules; _ } ->
      if modules = [] then scan_directory_for_ml_files "Library" dir
      else (
        Log.debug (fun m ->
            m "Library in %a has explicit modules: %a" Fpath.pp dir
              Fmt.(list ~sep:comma string)
              modules);
        files_of_modules dir modules)
  | Executable { names = _; dir; modules } ->
      if modules = [] then scan_directory_for_ml_files "Executable" dir
      else (
        Log.debug (fun m ->
            m "Executable in %a has explicit modules: %a" Fpath.pp dir
              Fmt.(list ~sep:comma string)
              modules);
        files_of_modules dir modules)
  | Test { dir; modules; _ } ->
      if modules = [] then scan_directory_for_ml_files "Test" dir
      else (
        Log.debug (fun m ->
            m "Test in %a has explicit modules: %a" Fpath.pp dir
              Fmt.(list ~sep:comma string)
              modules);
        files_of_modules dir modules)
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

(** Get library modules from describe (public libraries only).

    Returns both module basenames (from .ml files) and library names, so that
    [fuzz_tls.ml] matches a library named [tls] even when there is no [tls.ml]
    file (e.g. the library wraps multiple modules). *)
let lib_modules dune_describe =
  let public_libs =
    dune_describe.libraries
    |> List.filter (fun (lib_info : library_info) ->
        Option.is_some lib_info.public_name)
  in
  let lib_names =
    public_libs |> List.map (fun (lib_info : library_info) -> lib_info.name)
  in
  let file_modules =
    public_libs
    |> List.concat_map (fun (lib_info : library_info) -> lib_info.files)
    |> List.filter_map (fun file ->
        let file_str = Fpath.to_string file in
        if String.ends_with ~suffix:".ml" file_str then
          Some Fpath.(file |> rem_ext |> basename)
        else None)
  in
  lib_names @ file_modules |> List.sort_uniq String.compare

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

let cram_only_dirs dune_files =
  let cram_dirs =
    List.fold_left
      (fun acc dune_file ->
        let dir = Fpath.(dune_file |> parent |> normalize) in
        let stanzas = parse_dune_file dune_file in
        let has_cram =
          List.exists
            (function Sexp.List (Sexp.Atom "cram" :: _) -> true | _ -> false)
            stanzas
        in
        let has_other_stanzas =
          List.exists
            (function
              | Sexp.List (Sexp.Atom kind :: _)
                when kind = "test" || kind = "tests" || kind = "library"
                     || kind = "executable" || kind = "executables" ->
                  true
              | _ -> false)
            stanzas
        in
        if has_cram && not has_other_stanzas then (
          Log.debug (fun m ->
              m "Found cram-only directory: %s" (Fpath.to_string dir));
          dir :: acc)
        else acc)
      [] dune_files
  in
  Log.debug (fun m ->
      m "Total cram-only directories found: %d" (List.length cram_dirs));
  List.iter
    (fun dir -> Log.debug (fun m -> m "Cram dir: %s" (Fpath.to_string dir)))
    cram_dirs;
  cram_dirs

let is_under_cram_only_dir cram_dirs path =
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
        m "Path %s is under cram-only directory" (Fpath.to_string path_fp));
  result

let extract_items_from_dune_file cram_dirs dune_file =
  if should_include_dir dune_file then
    let dir = Fpath.(dune_file |> parent |> normalize) in
    if not (is_under_cram_only_dir cram_dirs dir) then
      let stanzas = parse_dune_file dune_file in
      List.filter_map (extract_project_item dir) stanzas
    else (
      Log.debug (fun m ->
          m "Skipping dune file in cram dir: %s (dir=%s)"
            (Fpath.to_string dune_file)
            (Fpath.to_string dir));
      [])
  else []

(** Get project structure from dune files *)
let project_structure project_root =
  let dune_files = files project_root in
  Log.debug (fun m ->
      m "Found %d dune files in %a" (List.length dune_files) Fpath.pp
        project_root);
  List.iter
    (fun f -> Log.debug (fun m -> m "  Dune file: %a" Fpath.pp f))
    dune_files;
  let cram_dirs = cram_only_dirs dune_files in
  let project_items =
    List.concat_map (extract_items_from_dune_file cram_dirs) dune_files
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
      | Library { name; public_name; dir; modules; private_modules } ->
          let files =
            item_files
              (Library { name; public_name; dir; modules; private_modules })
          in
          Some ({ name; public_name; files; private_modules } : library_info)
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

(** Check if [s1] contains [s2] as a substring. *)
let string_contains s1 s2 =
  let len2 = String.length s2 in
  let rec aux i =
    i + len2 <= String.length s1 && (String.sub s1 i len2 = s2 || aux (i + 1))
  in
  aux 0

(** Filter out files matching patterns *)
let exclude patterns describe =
  let filter_files files =
    List.filter
      (fun file ->
        let file_str = Fpath.to_string file in
        not
          (List.exists
             (fun pattern -> string_contains file_str pattern)
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
              private_modules = [];
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

(** Get executables from describe *)
let executables describe = describe.executables

(** Get tests from describe *)
let tests describe = describe.tests

let add_module_lib acc lib_name file =
  if Fpath.has_ext ".ml" file then
    let module_name = Fpath.(file |> rem_ext |> basename) in
    match List.assoc_opt module_name acc with
    | Some libs ->
        (module_name, lib_name :: libs) :: List.remove_assoc module_name acc
    | None -> (module_name, [ lib_name ]) :: acc
  else acc

let libraries_of_module describe =
  List.fold_left
    (fun acc (lib_info : library_info) ->
      List.fold_left
        (fun acc file -> add_module_lib acc lib_info.name file)
        acc lib_info.files)
    [] describe.libraries

let resolve_library describe name =
  let internal =
    List.find_opt
      (fun (lib_info : library_info) -> lib_info.public_name = Some name)
      describe.libraries
  in
  match internal with Some lib -> lib.name | None -> name

let test_file_library module_to_libs basename =
  if String.starts_with ~prefix:"test_" basename then
    let tested_module = String.sub basename 5 (String.length basename - 5) in
    match List.assoc_opt tested_module module_to_libs with
    | Some [ lib ] -> Some lib
    | _ -> None
  else None
