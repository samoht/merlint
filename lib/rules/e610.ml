(** E610: Test Without Library *)

module Issue_location = Location

type payload = { test_file : string; expected_module : string }

let log_src = Logs.Src.create "merlint.rules.e610" ~doc:"E610 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

(** Find "test/" in path, handling both absolute (/test/) and relative (test/)
    paths. Returns the index after "test/" if found. *)
let test_prefix path =
  match Astring.String.find_sub ~sub:"/test/" path with
  | Some idx -> Some (idx + 6)
  | None -> if String.starts_with ~prefix:"test/" path then Some 5 else None

(** Find "lib/" in path, handling both absolute (/lib/) and relative (lib/)
    paths. Returns the index after "lib/" if found. *)
let lib_prefix path =
  match Astring.String.find_sub ~sub:"/lib/" path with
  | Some idx -> Some (idx + 5)
  | None -> if String.starts_with ~prefix:"lib/" path then Some 4 else None

(** Extract the relative path from test/ directory. e.g., "test/foo/test_x.ml"
    -> "foo/x.ml" "test/test_x.ml" -> "x.ml" *)
let expected_lib_path test_file =
  let path = Fpath.to_string test_file in
  (* Find "test/" in the path and extract what comes after *)
  match test_prefix path with
  | Some idx ->
      let after_test = String.sub path idx (String.length path - idx) in
      (* Replace test_x.ml with x.ml *)
      let basename = Filename.basename after_test in
      let dirname = Filename.dirname after_test in
      if String.starts_with ~prefix:"test_" basename then
        let lib_basename = String.sub basename 5 (String.length basename - 5) in
        Some
          (if dirname = "." then lib_basename
           else Filename.concat dirname lib_basename)
      else None
  | None ->
      (* Fallback: just use basename *)
      let basename = Fpath.(test_file |> rem_ext |> basename) in
      if String.starts_with ~prefix:"test_" basename then
        Some (String.sub basename 5 (String.length basename - 5) ^ ".ml")
      else None

let library_module_path file =
  if not (Fpath.has_ext ".ml" file) then None
  else
    let path = Fpath.to_string file in
    match lib_prefix path with
    | Some idx ->
        let result = String.sub path idx (String.length path - idx) in
        Log.debug (fun m -> m "E610: lib path %s -> %s" path result);
        Some result
    | None ->
        Log.debug (fun m -> m "E610: lib path %s (no lib/ prefix)" path);
        Some path

let library_module_paths libraries =
  List.concat_map
    (fun lib -> List.filter_map library_module_path (Project_index.Library.files lib))
    libraries

let library_source_files libraries =
  List.concat_map
    (fun lib ->
      List.filter_map
        (fun file ->
          if Fpath.has_ext ".ml" file || Fpath.has_ext ".mli" file then
            Some (Fpath.to_string file)
          else None)
        (Project_index.Library.files lib))
    libraries

module String_set = Set.Make (String)

(** Project-wide set of module names referenced anywhere in [files]. The
    per-file view owns the typedtree/parsetree traversal cache; E610 only merges
    its module-name projection across library files. *)
let collect_referenced_modules ctx files =
  List.fold_left
    (fun acc path ->
      if Filename.check_suffix path ".ml" || Filename.check_suffix path ".mli"
      then
        try
          File_view.referenced_module_names (Context.file_view ctx path)
          |> List.fold_left (fun acc name -> String_set.add name acc) acc
        with Context.Analysis_error _ -> acc
      else acc)
    String_set.empty files

let module_path_matches ~expected_path lib_path =
  let expected_lc = String.lowercase_ascii expected_path in
  let expected_dir = String.lowercase_ascii (Filename.dirname expected_path) in
  let expected_base =
    String.lowercase_ascii (Filename.basename expected_path)
  in
  let lib_lc = String.lowercase_ascii lib_path in
  let lib_base = String.lowercase_ascii (Filename.basename lib_path) in
  lib_lc = expected_lc
  || lib_base = expected_base
     && (expected_dir = "."
        || String.starts_with ~prefix:(expected_dir ^ "/") lib_lc
        || (expected_dir = "" && lib_lc = lib_base)
        || Astring.String.is_infix
             ~affix:("/" ^ expected_dir ^ "/" ^ expected_base)
             lib_lc)

let missing_library_issue file expected_path =
  let loc =
    Issue_location.v ~file:(Fpath.to_string file) ~start_line:1 ~start_col:0
      ~end_line:1 ~end_col:0
  in
  Issue.v ~loc
    { test_file = Fpath.to_string file; expected_module = expected_path }

let check_test_file ~library_module_paths ~referenced_modules file =
  let test_module = Fpath.(file |> rem_ext |> basename) in
  if
    (not (Fpath.has_ext ".ml" file))
    || (not (String.starts_with ~prefix:"test_" test_module))
    || File.is_in_examples (Fpath.to_string file)
  then None
  else
    match expected_lib_path file with
    | None -> None
    | Some expected_path ->
        Log.debug (fun m ->
            m "E610: test %s expects lib %s" (Fpath.to_string file)
              expected_path);
        let found =
          List.exists (module_path_matches ~expected_path) library_module_paths
        in
        let module_name =
          Filename.remove_extension (Filename.basename expected_path)
        in
        let cap_name = String.capitalize_ascii module_name in
        let referenced = String_set.mem cap_name referenced_modules in
        Log.debug (fun m -> m "E610: found=%b referenced=%b" found referenced);
        if found || referenced then None
        else Some (missing_library_issue file expected_path)

let check ctx =
  let libraries = Project_query.source_libraries (Context.index ctx) in
  let library_module_paths = library_module_paths libraries in
  let referenced_modules =
    collect_referenced_modules ctx (library_source_files libraries)
  in
  Log.debug (fun m ->
      m "E610: library_module_paths = %a"
        Fmt.(list ~sep:comma string)
        library_module_paths);
  Context.test_stanzas ctx
  |> List.concat_map Project_index.source_stanza_files
  |> List.filter_map (check_test_file ~library_module_paths ~referenced_modules)

let pp ppf { test_file = _; expected_module } =
  Fmt.pf ppf "Test file exists but corresponding library module '%s' not found"
    expected_module

let rule =
  Rule.v ~code:"E610" ~title:"Test Without Library" ~category:Testing
    ~hint:
      "Every test module should have a corresponding library module. This \
       ensures that tests are testing actual library functionality rather than \
       testing code that doesn't exist in the library."
    ~examples:[] ~pp (Project check)
