(** E610: Test Without Library *)

type payload = { test_file : string; expected_module : string }

let check ctx =
  let files = Context.all_files ctx in

  (* Get all test_*.ml files from test directories *)
  let test_files =
    List.filter_map
      (fun file ->
        let basename = Filename.basename file in
        (* TODO: This is a bad heuristic - checking for "test" or "tests" in the path
           is brittle. We should use dune metadata to identify test executables/libraries
           properly. See TODO.md for more details. *)
        (* Check if it's in a test directory *)
        let in_test_dir =
          let parts = String.split_on_char '/' file in
          List.exists (fun p -> p = "test" || p = "tests") parts
        in
        if
          in_test_dir
          && String.starts_with ~prefix:"test_" basename
          && String.ends_with ~suffix:".ml" basename
        then
          (* Extract module name from test_<module>.ml *)
          let module_name =
            String.sub basename 5 (String.length basename - 8)
            (* Remove "test_" and ".ml" *)
          in
          Some (file, module_name)
        else None)
      files
  in

  (* Get all library module names *)
  let lib_module_names =
    List.filter_map
      (fun file ->
        let basename = Filename.basename file in
        (* TODO: Same issue here - checking for "lib" or "src" in the path is brittle.
           Should use dune metadata instead. *)
        (* Check if it's in a lib/src directory *)
        let in_lib_dir =
          let parts = String.split_on_char '/' file in
          List.exists (fun p -> p = "lib" || p = "src") parts
        in
        if in_lib_dir && String.ends_with ~suffix:".ml" basename then
          (* Extract module name *)
          let module_name = Filename.chop_extension basename in
          Some module_name
        else None)
      files
  in

  (* Find test files without corresponding library modules *)
  List.filter_map
    (fun (test_file, module_name) ->
      if not (List.mem module_name lib_module_names) then
        let loc =
          Location.create ~file:test_file ~start_line:1 ~start_col:0 ~end_line:1
            ~end_col:0
        in
        Some
          (Issue.v ~loc
             {
               test_file = Filename.basename test_file;
               expected_module = module_name ^ ".ml";
             })
      else None)
    test_files

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
