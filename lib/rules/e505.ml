(** E505: Missing MLI File *)

type payload = { ml_file : string; expected_mli : string }

let check (ctx : Context.project) =
  let files = Context.all_files ctx in
  (* Get executable and test module info once for all files *)
  let executable_modules = Context.executable_modules ctx in
  let test_modules = Context.test_modules ctx in

  let should_skip_module ml_file =
    let module_name = Filename.basename (Filename.remove_extension ml_file) in
    let module_name_capitalized = String.capitalize_ascii module_name in

    (* Skip if it's an executable *)
    let is_exe = List.mem module_name_capitalized executable_modules in

    (* Skip if it's a test module - check both regular and lowercase module names *)
    let is_test =
      List.mem module_name test_modules
      || List.mem module_name_capitalized test_modules
    in

    if is_exe then
      Logs.debug (fun m ->
          m "File %s is executable (module %s)" ml_file module_name_capitalized);
    if is_test then
      Logs.debug (fun m ->
          m "File %s is test module (module %s)" ml_file module_name);

    is_exe || is_test
  in

  (* For each ML file being analyzed, check if it has a corresponding MLI file *)
  List.filter_map
    (fun ml_file ->
      if String.ends_with ~suffix:".ml" ml_file then
        (* Only check for .mli files for library modules, not executables or test modules *)
        if not (should_skip_module ml_file) then
          let base_name = Filename.remove_extension ml_file in
          let mli_path = base_name ^ ".mli" in
          (* Check if the MLI file exists in the list of project files *)
          if not (List.mem mli_path files) then
            let loc =
              Location.create ~file:ml_file ~start_line:1 ~start_col:0
                ~end_line:1 ~end_col:0
            in
            Some (Issue.v ~loc { ml_file; expected_mli = mli_path })
          else None
        else None
      else None)
    files

let pp ppf { ml_file; expected_mli } =
  Fmt.pf ppf "Library module %s is missing interface file %s" ml_file
    expected_mli

let rule =
  Rule.v ~code:"E505" ~title:"Missing MLI File" ~category:Project_structure
    ~hint:
      "Library modules should have corresponding .mli files for proper \
       encapsulation and API documentation. Create interface files to hide \
       implementation details and provide a clean API."
    ~examples:
      [ Example.bad Examples.E505.bad_ml; Example.good Examples.E505.good_mli ]
    ~pp (Project check)
