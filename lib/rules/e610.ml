(** E610: Test Without Library *)

type payload = { test_file : string; expected_module : string }

(** Find "test/" in path, handling both absolute (/test/) and relative (test/)
    paths. Returns the index after "test/" if found. *)
let find_test_prefix path =
  match Astring.String.find_sub ~sub:"/test/" path with
  | Some idx -> Some (idx + 6)
  | None -> if String.starts_with ~prefix:"test/" path then Some 5 else None

(** Find "lib/" in path, handling both absolute (/lib/) and relative (lib/)
    paths. Returns the index after "lib/" if found. *)
let find_lib_prefix path =
  match Astring.String.find_sub ~sub:"/lib/" path with
  | Some idx -> Some (idx + 5)
  | None -> if String.starts_with ~prefix:"lib/" path then Some 4 else None

(** Extract the relative path from test/ directory. e.g., "test/foo/test_x.ml"
    -> "foo/x.ml" "test/test_x.ml" -> "x.ml" *)
let expected_lib_path test_file =
  let path = Fpath.to_string test_file in
  (* Find "test/" in the path and extract what comes after *)
  match find_test_prefix path with
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

let check ctx =
  let dune_describe = Context.dune_describe ctx in

  (* Build a set of library module paths (relative to lib/) *)
  let libraries = Dune.libraries dune_describe in
  let library_module_paths =
    List.concat_map
      (fun (lib_info : Dune.library_info) ->
        List.filter_map
          (fun file ->
            if Fpath.has_ext ".ml" file then (
              let path = Fpath.to_string file in
              (* Extract path relative to lib/ *)
              match find_lib_prefix path with
              | Some idx ->
                  let result = String.sub path idx (String.length path - idx) in
                  Logs.debug (fun m -> m "E610: lib path %s -> %s" path result);
                  Some result
              | None ->
                  Logs.debug (fun m ->
                      m "E610: lib path %s (no lib/ prefix)" path);
                  Some (Fpath.to_string file))
            else None)
          lib_info.files)
      libraries
  in

  (* Collect all library source file paths for sub-module reference checking *)
  let library_source_files =
    List.concat_map
      (fun (lib_info : Dune.library_info) ->
        List.filter_map
          (fun file ->
            if Fpath.has_ext ".ml" file || Fpath.has_ext ".mli" file then
              Some (Fpath.to_string file)
            else None)
          lib_info.files)
      libraries
  in

  (* Check if [module_name] (e.g. "Dump") is referenced as a module in any
     library source file. Looks for patterns like [Foo.Dump.] or
     [module Dump]. *)
  let is_referenced_in_library module_name =
    let cap_name = String.capitalize_ascii module_name in
    let pattern_dot = cap_name ^ "." in
    let pattern_module = "module " ^ cap_name in
    List.exists
      (fun src_path ->
        try
          let content =
            In_channel.with_open_text src_path In_channel.input_all
          in
          Astring.String.is_infix ~affix:pattern_dot content
          || Astring.String.is_infix ~affix:pattern_module content
        with _ -> false)
      library_source_files
  in

  Logs.debug (fun m ->
      m "E610: library_module_paths = %a"
        Fmt.(list ~sep:comma string)
        library_module_paths);

  (* Check each test file *)
  let issues = ref [] in
  List.iter
    (fun test_info ->
      List.iter
        (fun file ->
          if Fpath.has_ext ".ml" file then
            let test_module = Fpath.(file |> rem_ext |> basename) in
            if
              String.starts_with ~prefix:"test_" test_module
              && not (File.is_in_examples (Fpath.to_string file))
            then
              match expected_lib_path file with
              | Some expected_path ->
                  Logs.debug (fun m ->
                      m "E610: test %s expects lib %s" (Fpath.to_string file)
                        expected_path);
                  let found =
                    List.exists
                      (fun lib_path ->
                        lib_path = expected_path
                        || Filename.basename lib_path = expected_path)
                      library_module_paths
                  in
                  (* Also check if the expected module name is referenced as a
                     sub-module or dependency module in any library source file *)
                  let module_name =
                    Filename.remove_extension (Filename.basename expected_path)
                  in
                  let referenced = is_referenced_in_library module_name in
                  Logs.debug (fun m ->
                      m "E610: found=%b referenced=%b" found referenced);
                  if (not found) && not referenced then
                    let loc =
                      Location.v ~file:(Fpath.to_string file) ~start_line:1
                        ~start_col:0 ~end_line:1 ~end_col:0
                    in
                    issues :=
                      Issue.v ~loc
                        {
                          test_file = Fpath.to_string file;
                          expected_module = expected_path;
                        }
                      :: !issues
              | None -> ())
        test_info.Dune.files)
    (Dune.tests dune_describe);
  List.rev !issues

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
