(** E605: Missing Test File *)

type payload = { module_name : string; expected_test_file : string }

(** Check if a module only contains type definitions and module aliases *)
let contains_only_types_and_modules file_path =
  try
    let ic = open_in file_path in
    let lexbuf = Lexing.from_channel ic in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = file_path };
    let structure = Parse.implementation lexbuf in
    close_in ic;

    (* Check if all items are type definitions or module aliases *)
    List.for_all
      (fun item ->
        match item.Parsetree.pstr_desc with
        | Pstr_type _ -> true (* Type definitions *)
        | Pstr_typext _ -> true (* Type extensions *)
        | Pstr_module { pmb_expr; _ } -> (
            (* Check for module aliases and applications *)
            match pmb_expr.pmod_desc with
            | Pmod_ident _ ->
                true (* Module alias like: module M = OtherModule *)
            | Pmod_apply _ ->
                true (* Module application like: module M = Map.Make(String) *)
            | _ -> false)
        | Pstr_modtype _ -> true (* Module type definitions *)
        | Pstr_open _ -> true (* Open statements *)
        | Pstr_include _ -> true (* Include statements *)
        | Pstr_attribute _ -> true (* Attributes *)
        | _ -> false) (* Any other construct means it has implementation *)
      structure
  with _ -> false (* If we can't parse, assume it needs tests *)

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
        Location.v ~file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    | None ->
        Location.v ~file:"dune" ~start_line:1 ~start_col:0 ~end_line:1
          ~end_col:0
  in
  Issue.v ~loc
    { module_name; expected_test_file = Fmt.str "test_%s.ml" module_name }

let check (ctx : Context.project) =
  let files = Context.all_files ctx in
  let lib_modules = Context.lib_modules ctx in
  let test_modules = Context.test_modules ctx in

  (* E605 checks if library modules have corresponding test files.
     First check dune metadata, then check actual files being analyzed. *)

  (* Debug logging *)
  Logs.debug (fun m ->
      m "E605: Checking %d library modules" (List.length lib_modules));
  Logs.debug (fun m ->
      m "E605: Found %d test modules in dune" (List.length test_modules));
  Logs.debug (fun m ->
      m "E605: Test modules: %a" Fmt.(list ~sep:comma string) test_modules);
  Logs.debug (fun m -> m "E605: Analyzing %d files" (List.length files));

  (* Log test files found in the files list *)
  let test_files_in_list =
    files
    |> List.filter (fun f ->
           String.ends_with ~suffix:".ml" f
           &&
           let basename = Filename.basename f |> Filename.remove_extension in
           String.starts_with ~prefix:"test_" basename || basename = "test")
  in
  Logs.debug (fun m ->
      m "E605: Test .ml files in analyzed files: %d"
        (List.length test_files_in_list));
  List.iter
    (fun f -> Logs.debug (fun m -> m "E605:   - %s" f))
    test_files_in_list;

  if List.length test_files_in_list = 0 && List.length lib_modules > 0 then
    Logs.debug (fun m ->
        m
          "E605: No test files found in analyzed files. Make sure to include \
           test directories in the analysis (e.g., 'merlint lib test' instead \
           of just 'merlint lib')");

  let missing_tests =
    List.filter
      (fun lib_mod ->
        (* Skip if this is already a test module *)
        if String.starts_with ~prefix:"test_" lib_mod then false
        else
          (* Find the source file for this module *)
          let module_file =
            List.find_opt
              (fun f ->
                String.ends_with ~suffix:".ml" f
                && Filename.basename (Filename.remove_extension f) = lib_mod)
              files
          in
          match module_file with
          | Some file_path when contains_only_types_and_modules file_path ->
              Logs.debug (fun m ->
                  m "E605: Skipping module '%s' (contains only types/modules)"
                    lib_mod);
              false
          | _ ->
              let expected_test_name = "test_" ^ lib_mod in

              (* Debug what we're checking *)
              let in_dune = List.mem expected_test_name test_modules in
              let in_files =
                List.exists
                  (fun f ->
                    String.ends_with ~suffix:".ml" f
                    && Filename.basename (Filename.remove_extension f)
                       = expected_test_name)
                  files
              in

              Logs.debug (fun m ->
                  m "E605: Checking %s -> %s (in_dune=%b, in_files=%b)" lib_mod
                    expected_test_name in_dune in_files);

              (* Check both:
                 1. If test module exists in dune metadata (test_modules)
                 2. If test file exists in the files being analyzed *)
              (not in_dune) && not in_files)
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
