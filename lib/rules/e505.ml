(** E505: Missing MLI File *)

type payload = { ml_file : string; expected_mli : string }

let check (ctx : Context.project) =
  let files = Context.all_files ctx in
  (* Get executable info once for all files *)
  let executable_modules = Context.executable_modules ctx in
  let is_executable_module ml_file =
    let module_name = Filename.basename (Filename.remove_extension ml_file) in
    let module_name_capitalized = String.capitalize_ascii module_name in
    let is_exe = List.mem module_name_capitalized executable_modules in
    if is_exe then
      Logs.debug (fun m ->
          m "File %s is executable (module %s)" ml_file module_name_capitalized);
    is_exe
  in

  List.filter_map
    (fun ml_file ->
      if String.ends_with ~suffix:".ml" ml_file then
        (* Only check for .mli files for library modules, not executables *)
        if not (is_executable_module ml_file) then
          let base_name = Filename.remove_extension ml_file in
          let mli_path = base_name ^ ".mli" in
          if not (Sys.file_exists mli_path) then
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
    ~examples:[] ~pp (Project check)
