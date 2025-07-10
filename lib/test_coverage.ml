(** Test coverage checks

    This module ensures that library modules have corresponding test files. *)

(** Check if a library is local *)
let is_local_library lib_contents =
  List.exists
    (function
      | Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "local"; value ] -> (
          match value with Sexplib0.Sexp.Atom "true" -> true | _ -> false)
      | _ -> false)
    lib_contents

(** Check if a module is generated (ends with .ml-gen) *)
let is_generated_module items =
  List.exists
    (function
      | Sexplib0.Sexp.List
          [
            Sexplib0.Sexp.Atom "impl";
            Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom path ];
          ] ->
          String.ends_with ~suffix:".ml-gen" path
      | _ -> false)
    items

(** Extract module name from a module description *)
let extract_module_name items =
  match
    List.find_map
      (function
        | Sexplib0.Sexp.List
            [ Sexplib0.Sexp.Atom "name"; Sexplib0.Sexp.Atom name ] ->
            Some (String.lowercase_ascii name)
        | _ -> None)
      items
  with
  | Some name when String.ends_with ~suffix:"__" name ->
      (* Skip dune-generated wrapper modules like "prune__" *)
      None
  | Some name -> Some name
  | None -> None

(** Process a single module from dune describe *)
let process_module = function
  | Sexplib0.Sexp.List items ->
      if is_generated_module items then None else extract_module_name items
  | _ -> None

(** Extract modules from a modules list *)
let extract_modules = function
  | Sexplib0.Sexp.List
      (Sexplib0.Sexp.Atom "modules" :: [ Sexplib0.Sexp.List modules ]) ->
      List.filter_map process_module modules
  | _ -> []

(** Process library fields to find modules *)
let process_library_fields = function
  | Sexplib0.Sexp.List fields -> List.concat_map extract_modules fields
  | _ -> []

(** Extract library modules from dune describe output *)
let extract_library_modules_from_sexp sexp =
  match sexp with
  | Sexplib0.Sexp.List items ->
      List.concat_map
        (function
          | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "library" :: lib_contents) ->
              if is_local_library lib_contents then
                List.concat_map process_library_fields lib_contents
              else []
          | _ -> [])
        items
  | _ -> []

let get_lib_modules project_root =
  match Dune.run_dune_describe project_root with
  | Error err ->
      Logs.warn (fun m -> m "Could not run dune describe: %s" err);
      []
  | Ok sexp_str -> (
      try
        let sexp = Parsexp.Single.parse_string_exn sexp_str in
        let modules = extract_library_modules_from_sexp sexp in
        (* Filter out test-related modules *)
        List.filter
          (fun m ->
            (not (String.starts_with ~prefix:"test_" m))
            && not (String.ends_with ~suffix:"_test" m))
          modules
      with exn ->
        Logs.err (fun m ->
            m "Failed to parse dune describe output: %s"
              (Printexc.to_string exn));
        [])

let get_test_modules files =
  let test_files =
    files
    |> List.filter (fun f ->
           String.starts_with ~prefix:"test/" f
           && String.ends_with ~suffix:".ml" f
           && not (String.ends_with ~suffix:".mli" f))
  in
  let test_modules =
    test_files
    |> List.map (fun f ->
           let base = Filename.basename f |> Filename.remove_extension in
           (* Extract the module being tested from test_<module>.ml *)
           if String.starts_with ~prefix:"test_" base then
             Some (String.sub base 5 (String.length base - 5))
           else if base = "test" then None (* Main test runner *)
           else Some base)
    |> List.filter_map Fun.id
  in
  test_modules

let create_missing_test_issue module_name files =
  let lib_file =
    List.find_opt
      (fun f ->
        String.ends_with ~suffix:(Fmt.str "/%s.ml" module_name) f
        || f = Fmt.str "%s.ml" module_name)
      files
  in
  let location =
    match lib_file with
    | Some file -> Location.create ~file ~line:1 ~col:0
    | None -> Location.create ~file:(Fmt.str "%s.ml" module_name) ~line:1 ~col:0
  in
  Issue.Missing_test_file
    {
      module_name;
      expected_test_file = Fmt.str "test_%s.ml" module_name;
      location;
    }

let create_extra_test_issue test_module files =
  let test_file = Fmt.str "test_%s.ml" test_module in
  let location =
    match
      List.find_opt (fun f -> String.ends_with ~suffix:test_file f) files
    with
    | Some file -> Location.create ~file ~line:1 ~col:0
    | None -> Location.create ~file:test_file ~line:1 ~col:0
  in
  Issue.Test_without_library
    { test_file; expected_module = Fmt.str "%s.ml" test_module; location }

let check_test_coverage project_root files =
  let lib_modules = get_lib_modules project_root in
  let test_modules = get_test_modules files in

  let missing_tests =
    List.filter (fun lib_mod -> not (List.mem lib_mod test_modules)) lib_modules
  in

  let extra_tests =
    List.filter
      (fun test_mod -> not (List.mem test_mod lib_modules))
      test_modules
  in

  let missing_test_issues =
    List.map (fun m -> create_missing_test_issue m files) missing_tests
  in
  let extra_test_issues =
    List.map (fun m -> create_extra_test_issue m files) extra_tests
  in
  missing_test_issues @ extra_test_issues

(** Check if test.ml includes all test suites *)
let check_test_runner_completeness files =
  (* Find test.ml *)
  let test_ml =
    List.find_opt
      (fun f ->
        f = "test/test.ml" || String.ends_with ~suffix:"/test/test.ml" f)
      files
  in

  match test_ml with
  | None -> []
  | Some test_file -> (
      try
        let content =
          In_channel.with_open_text test_file In_channel.input_all
        in
        let test_modules = get_test_modules files in

        (* Check if each test module's suite is included *)
        let missing_suites =
          List.filter
            (fun mod_name ->
              let suite_pattern = Fmt.str "Test_%s.suite" mod_name in
              not (Re.execp (Re.compile (Re.str suite_pattern)) content))
            test_modules
        in

        List.map
          (fun mod_name ->
            Issue.Test_suite_not_included
              {
                test_module = Fmt.str "Test_%s" mod_name;
                test_runner_file = test_file;
                location = Location.create ~file:test_file ~line:1 ~col:0;
              })
          missing_suites
      with _ -> [])
