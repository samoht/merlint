(** E610: Test Without Library *)

type payload = { test_file : string; expected_module : string }

let check ctx =
  let lib_modules = Context.lib_modules ctx in
  let test_modules = Context.test_modules ctx in
  let files = Context.all_files ctx in

  (* Find test modules that don't have corresponding library modules *)
  List.filter_map
    (fun test_module ->
      if String.starts_with ~prefix:"test_" test_module then
        let expected_lib_module =
          String.sub test_module 5 (String.length test_module - 5)
        in
        if not (List.mem expected_lib_module lib_modules) then
          (* Find the test file to get its location *)
          let test_file_opt =
            List.find_opt
              (fun f ->
                String.ends_with ~suffix:".ml" f
                && Filename.basename (Filename.remove_extension f) = test_module)
              files
          in
          match test_file_opt with
          | Some test_file ->
              let loc =
                Location.create ~file:test_file ~start_line:1 ~start_col:0
                  ~end_line:1 ~end_col:0
              in
              Some
                (Issue.v ~loc
                   {
                     test_file = Filename.basename test_file;
                     expected_module = expected_lib_module ^ ".ml";
                   })
          | None -> None
        else None
      else None)
    test_modules

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
