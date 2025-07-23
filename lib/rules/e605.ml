(** E605: Missing Test File *)

type payload = { module_name : string; expected_test_file : string }

(** Creates a missing test file issue for a library module without corresponding
    test *)
let create_missing_test_issue module_name files =
  (* Find the source file to generate a location *)
  let loc =
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
  Issue.v ~loc
    { module_name; expected_test_file = Fmt.str "test_%s.ml" module_name }

let check (ctx : Context.project) =
  let files = Context.all_files ctx in
  let lib_modules = Context.lib_modules ctx in
  let test_modules = Context.test_modules ctx in

  let missing_tests =
    List.filter
      (fun lib_mod ->
        let expected_test_module = "test_" ^ lib_mod in
        not (List.mem expected_test_module test_modules))
      lib_modules
  in

  List.map (fun m -> create_missing_test_issue m files) missing_tests

let pp ppf { module_name; expected_test_file } =
  Fmt.pf ppf "Library module %s is missing test file %s" module_name
    expected_test_file

let rule =
  Rule.v ~code:"E605" ~title:"Missing Test File" ~category:Testing
    ~hint:
      "Each library module should have a corresponding test file to ensure \
       proper testing coverage. Create test files following the naming \
       convention test_<module>.ml"
    ~examples:[] ~pp (Project check)
