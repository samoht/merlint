(** E610: Test Without Library *)

type payload = { test_file : string; expected_module : string }

let check ctx =
  let dune_describe = Context.dune_describe ctx in

  (* Build a set of library modules for each library *)
  let library_modules =
    List.fold_left
      (fun acc (lib_name, files) ->
        let modules =
          List.filter_map
            (fun file ->
              if Fpath.has_ext ".ml" file then
                Some Fpath.(file |> rem_ext |> basename)
              else None)
            files
        in
        (lib_name, modules) :: acc)
      []
      (Dune.get_libraries dune_describe)
  in

  (* Check each test file *)
  let issues = ref [] in
  List.iter
    (fun (test_stanza, files) ->
      List.iter
        (fun file ->
          if Fpath.has_ext ".ml" file then
            let test_module = Fpath.(file |> rem_ext |> basename) in
            if String.starts_with ~prefix:"test_" test_module then
              let expected_lib_module =
                String.sub test_module 5 (String.length test_module - 5)
              in
              (* Check if this library module exists in the expected library *)
              (* For test stanza "test" or starting with "test_", check all libraries; 
                 otherwise check specific library *)
              let found =
                if
                  test_stanza = "test"
                  || String.starts_with ~prefix:"test_" test_stanza
                then
                  (* Generic test stanza - check if module exists in any library *)
                  List.exists
                    (fun (_, modules) -> List.mem expected_lib_module modules)
                    library_modules
                else
                  (* Specific test stanza matching a library name - check if module exists in that library *)
                  match List.assoc_opt test_stanza library_modules with
                  | Some modules -> List.mem expected_lib_module modules
                  | None -> false
              in
              if not found then
                let loc =
                  Location.create ~file:(Fpath.to_string file) ~start_line:1
                    ~start_col:0 ~end_line:1 ~end_col:0
                in
                issues :=
                  Issue.v ~loc
                    {
                      test_file = Fpath.to_string file;
                      expected_module = expected_lib_module ^ ".ml";
                    }
                  :: !issues)
        files)
    (Dune.get_tests dune_describe);
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
