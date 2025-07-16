(** E610: Test Without Library *)

let create_extra_test_issue test_module files =
  (* Find the test file to generate a location *)
  let test_file = Fmt.str "test_%s.ml" (String.lowercase_ascii test_module) in
  let location =
    match
      List.find_opt (fun f -> String.ends_with ~suffix:test_file f) files
    with
    | Some file ->
        Location.create ~file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    | None ->
        Location.create ~file:test_file ~start_line:1 ~start_col:0 ~end_line:1
          ~end_col:0
  in
  Issue.Test_without_library
    { test_file; expected_module = Fmt.str "%s.ml" test_module; location }

let check ctx =
  match ctx with
  | Context.File _ ->
      failwith "E610 is a project-wide rule but received file context"
  | Context.Project ctx ->
      let files = Context.all_files (Context.Project ctx) in
      let lib_modules = Context.lib_modules (Context.Project ctx) in
      let test_modules = Context.test_modules (Context.Project ctx) in

      let extra_tests =
        List.filter
          (fun test_mod -> not (List.mem test_mod lib_modules))
          test_modules
      in

      List.map (fun m -> create_extra_test_issue m files) extra_tests
