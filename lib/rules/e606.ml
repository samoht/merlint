(** E606: Test File in Wrong Location *)

type payload = {
  test_module : string;
  library_name : string;
  test_stanza : string;
}

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in

  (* Build a map from module names to their library *)
  let module_to_library =
    List.fold_left
      (fun acc (lib_name, files) ->
        List.fold_left
          (fun acc file ->
            if Fpath.has_ext ".ml" file then
              let module_name = Fpath.(file |> rem_ext |> basename) in
              (module_name, lib_name) :: acc
            else acc)
          acc files)
      []
      (Dune.get_libraries dune_describe)
  in

  (* Build a map from test modules to their test stanza *)
  let test_module_to_stanza =
    List.fold_left
      (fun acc (test_name, files) ->
        List.fold_left
          (fun acc file ->
            if Fpath.has_ext ".ml" file then
              let module_name = Fpath.(file |> rem_ext |> basename) in
              (module_name, test_name) :: acc
            else acc)
          acc files)
      []
      (Dune.get_tests dune_describe)
  in

  (* Check each test module to see if it's in the right test stanza *)
  List.filter_map
    (fun (test_module, test_stanza) ->
      if String.starts_with ~prefix:"test_" test_module then
        let lib_module =
          String.sub test_module 5 (String.length test_module - 5)
        in
        (* Find which library this module belongs to *)
        match List.assoc_opt lib_module module_to_library with
        | Some lib_name ->
            (* Check if the test stanza matches the library name *)
            (* We allow "test" as a generic test stanza name *)
            if test_stanza <> lib_name && test_stanza <> "test" then
              (* Find the test file for location *)
              match
                List.find_opt
                  (fun (_, files) ->
                    List.exists
                      (fun f ->
                        Fpath.has_ext ".ml" f
                        && Fpath.(f |> rem_ext |> basename) = test_module)
                      files)
                  (Dune.get_tests dune_describe)
              with
              | Some (_, files) -> (
                  match
                    List.find_opt
                      (fun f ->
                        Fpath.has_ext ".ml" f
                        && Fpath.(f |> rem_ext |> basename) = test_module)
                      files
                  with
                  | Some file ->
                      let loc =
                        Location.create ~file:(Fpath.to_string file)
                          ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
                      in
                      Some
                        (Issue.v ~loc
                           { test_module; library_name = lib_name; test_stanza })
                  | None -> None)
              | None -> None
            else None
        | None -> None (* Module not found in any library *)
      else None)
    test_module_to_stanza

let pp ppf { test_module; library_name; test_stanza } =
  Fmt.pf ppf
    "Test module '%s' tests library '%s' but is in test stanza '%s' (expected \
     test stanza '%s' or 'test')"
    test_module library_name test_stanza library_name

let rule =
  Rule.v ~code:"E606" ~title:"Test File in Wrong Test Stanza" ~category:Testing
    ~hint:
      "Test files should be organized to match the library structure. Tests \
       for modules in a library should be grouped together in a test stanza \
       that matches the library name, or in a generic 'test' stanza."
    ~examples:
      [
        Example.bad Examples.E606.Bad.test_utils_ml;
        Example.good Examples.E606.Good.parser_ml;
      ]
    ~pp (Project check)
