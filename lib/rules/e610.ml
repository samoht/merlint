(** E610: Test Without Library *)

type payload = { test_file : string; expected_module : string }

let create_extra_test_issue test_module files =
  (* Find the test file to generate a location *)
  let test_file = Fmt.str "test_%s.ml" (String.lowercase_ascii test_module) in
  let loc =
    match
      List.find_opt (fun f -> String.ends_with ~suffix:test_file f) files
    with
    | Some file ->
        Location.create ~file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    | None ->
        Location.create ~file:test_file ~start_line:1 ~start_col:0 ~end_line:1
          ~end_col:0
  in
  Issue.v ~loc { test_file; expected_module = Fmt.str "%s.ml" test_module }

let check ctx =
  let files = Context.all_files ctx in
  let lib_modules = Context.lib_modules ctx in
  let test_modules = Context.test_modules ctx in

  let extra_tests =
    List.filter
      (fun test_mod -> not (List.mem test_mod lib_modules))
      test_modules
  in

  List.map (fun m -> create_extra_test_issue m files) extra_tests

let pp ppf { test_file; expected_module } =
  Fmt.pf ppf
    "Test file '%s' exists but corresponding library module '%s' not found"
    test_file expected_module

let rule =
  Rule.v ~code:"E610" ~title:"Test Without Library" ~category:Testing
    ~hint:
      "Every test module should have a corresponding library module. This \
       ensures that tests are testing actual library functionality rather than \
       testing code that doesn't exist in the library."
    ~examples:[] ~pp (Project check)
