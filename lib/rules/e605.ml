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

  (* E605 checks if library modules have corresponding test files.
     Only check if we're analyzing files from a library directory AND
     we can see the whole project structure (e.g., test directories). *)

  (* Check if we're only analyzing a subset of the project *)
  let analyzing_subset =
    List.exists (fun f -> String.contains f '/') files
    && not
         (List.exists
            (fun f ->
              String.contains f '/' && String.contains f '.'
              && String.contains (Filename.dirname f) '/'
              && Filename.basename (Filename.dirname f) = "test")
            files)
  in

  if analyzing_subset then
    (* We're only analyzing part of the project (e.g., just lib/), 
       so we can't reliably check for test files *)
    []
  else
    (* We can see the full project structure, so check for test files *)
    let missing_tests =
      List.filter
        (fun lib_mod ->
          let expected_test_name = "test_" ^ lib_mod in
          (* Check if test file exists in the files list *)
          not
            (List.exists
               (fun f ->
                 String.ends_with ~suffix:".ml" f
                 && Filename.basename (Filename.remove_extension f)
                    = expected_test_name)
               files))
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
