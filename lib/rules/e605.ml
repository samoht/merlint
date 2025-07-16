(** E605: Missing Test File *)

(** Creates a missing test file issue for a library module without corresponding
    test *)
let create_missing_test_issue module_name files =
  (* Find the source file to generate a location *)
  let location =
    match
      List.find_opt
        (fun f ->
          let basename = Filename.basename f |> Filename.remove_extension in
          String.lowercase_ascii basename = String.lowercase_ascii module_name)
        files
    with
    | Some file ->
        Location.create ~file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    | None ->
        Location.create ~file:"dune" ~start_line:1 ~start_col:0 ~end_line:1
          ~end_col:0
  in
  Issue.Missing_test_file
    {
      module_name;
      expected_test_file = Fmt.str "test_%s.ml" module_name;
      location;
    }

let check ctx =
  match ctx with
  | Context.File _ ->
      failwith "E605 is a project-wide rule but received file context"
  | Context.Project _ ->
      let files = Context.all_files ctx in
      let lib_modules = Context.lib_modules ctx in
      let test_modules = Context.test_modules ctx in

      let missing_tests =
        List.filter
          (fun lib_mod -> not (List.mem lib_mod test_modules))
          lib_modules
      in

      List.map (fun m -> create_missing_test_issue m files) missing_tests
