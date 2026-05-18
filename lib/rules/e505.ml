(** E505: Missing MLI File *)

type payload = { ml_file : string; expected_mli : string }

let log_src = Logs.Src.create "merlint.rules.e505" ~doc:"E505 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

let is_test_module module_name module_name_capitalized test_modules =
  List.mem module_name test_modules
  || List.mem module_name_capitalized test_modules
  || String.starts_with ~prefix:"test_" module_name

let should_skip_module ~executable_modules ~test_modules ml_file =
  let module_name = Filename.basename (Filename.remove_extension ml_file) in
  let module_name_capitalized = String.capitalize_ascii module_name in
  let is_exe = List.mem module_name_capitalized executable_modules in
  let is_test =
    is_test_module module_name module_name_capitalized test_modules
  in
  let is_intf = String.ends_with ~suffix:"_intf" module_name in
  if is_exe then
    Log.debug (fun m ->
        m "File %s is executable (module %s)" ml_file module_name_capitalized);
  if is_test then
    Log.debug (fun m ->
        m "File %s is test module (module %s)" ml_file module_name);
  if is_intf then
    Log.debug (fun m -> m "File %s is interface definition file" ml_file);
  is_exe || is_test || is_intf

let is_virtual_impl ctx ml_file =
  let dir = Filename.dirname ml_file in
  let dune_path = Filename.concat dir "dune" in
  try
    let content = Context.file_content ctx dune_path in
    match Dune.File.of_string content with
    | Error _ -> false
    | Ok dune ->
        Dune.File.libraries dune
        |> List.exists (fun lib -> Dune.File.Library.implements lib <> None)
  with File_view.Analysis_error _ -> false

let missing_mli_issue files ml_file =
  let mli_path = Filename.remove_extension ml_file ^ ".mli" in
  if List.mem mli_path files then None
  else
    let loc =
      Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    in
    Some (Issue.v ~loc { ml_file; expected_mli = mli_path })

let check_file ctx ~files ~executable_modules ~test_modules ml_file =
  if not (File_kind.is_ml ml_file) then None
  else if should_skip_module ~executable_modules ~test_modules ml_file then None
  else if is_virtual_impl ctx ml_file then None
  else missing_mli_issue files ml_file

let check (ctx : Context.project) =
  let files = Context.analyze_set ctx in
  let executable_modules = Context.executable_modules ctx in
  let test_modules = Context.test_modules ctx in
  List.filter_map
    (check_file ctx ~files ~executable_modules ~test_modules)
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
