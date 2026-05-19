(** E505: Missing MLI File *)

type payload = { ml_file : string; expected_mli : string }

let log_src = Logs.Src.create "merlint.rules.e505" ~doc:"E505 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)
module String_set = Set.Make (String)

type env = {
  files : String_set.t;
  exes : String_set.t;
  tests : String_set.t;
  libs : String_set.t;
  virtuals : String_set.t;
}

type work = { env : env; file : string }

let string_set xs =
  List.fold_left (fun acc x -> String_set.add x acc) String_set.empty xs

let is_test_module module_name module_name_capitalized test_modules =
  String_set.mem module_name test_modules
  || String_set.mem module_name_capitalized test_modules
  || String.starts_with ~prefix:"test_" module_name

let should_skip_module ~executable_modules ~test_modules ml_file =
  let module_name = Filename.basename (Filename.remove_extension ml_file) in
  let module_name_capitalized = String.capitalize_ascii module_name in
  let is_exe = String_set.mem module_name_capitalized executable_modules in
  let is_test =
    is_test_module module_name module_name_capitalized test_modules
  in
  let is_companion = File.is_unit_companion_module module_name in
  if is_exe then
    Log.debug (fun m ->
        m "File %s is executable (module %s)" ml_file module_name_capitalized);
  if is_test then
    Log.debug (fun m ->
        m "File %s is test module (module %s)" ml_file module_name);
  if is_companion then
    Log.debug (fun m -> m "File %s is unit companion module" ml_file);
  is_exe || is_test || is_companion

let source_path ~root file =
  let file = Fpath.v file in
  if Fpath.is_abs file then Fpath.normalize file
  else Fpath.normalize Fpath.(v root // file)

let is_library_file ~root index file =
  let file = source_path ~root file in
  Project_index.libraries_of_file index file <> []
  || Project_index.has_library_stanza_in_dir index (Fpath.parent file)

let is_virtual_impl_file ~root index file =
  let file = source_path ~root file in
  Project_index.libraries_of_file index file
  |> List.exists Project_index.Library.is_virtual_implementation

let missing_mli_issue files ml_file =
  let mli_path = Filename.remove_extension ml_file ^ ".mli" in
  if String_set.mem mli_path files then None
  else
    let loc =
      Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    in
    Some (Issue.v ~loc { ml_file; expected_mli = mli_path })

let check_file ~library_files ~virtual_impl_files ~files ~executable_modules
    ~test_modules ml_file =
  if not (File_kind.is_ml ml_file) then None
  else if not (String_set.mem ml_file library_files) then None
  else
    let module_name = Filename.basename (Filename.remove_extension ml_file) in
    let is_companion = File.is_unit_companion_module module_name in
    if is_companion then None
    else if should_skip_module ~executable_modules ~test_modules ml_file then
      (* For a library-owned module, only executable ownership should suppress
         E505. Test-shaped names such as [test_helpers] still need interfaces
         when dune metadata says they belong to a library. *)
      let module_name_capitalized = String.capitalize_ascii module_name in
      if String_set.mem module_name_capitalized executable_modules then None
      else missing_mli_issue files ml_file
    else if String_set.mem ml_file virtual_impl_files then None
    else missing_mli_issue files ml_file

let enumerate ctx =
  let files = Context.analyze_set ctx in
  let ml_files = List.filter File_kind.is_ml files in
  let executable_modules = Context.executable_modules ctx in
  let test_modules = Context.test_modules ctx in
  let root = Context.project_root ctx in
  let index = Context.index ctx in
  let root_path = Fpath.v root in
  let project_files =
    Project_index.source_files index
    |> List.map (fun file ->
        Loc.relative_to ~root:root_path file |> Fpath.to_string)
  in
  let library_files =
    List.filter (is_library_file ~root index) ml_files |> string_set
  in
  let virtual_files =
    List.filter (is_virtual_impl_file ~root index) ml_files |> string_set
  in
  let env =
    {
      files = string_set project_files;
      exes = string_set executable_modules;
      tests = string_set test_modules;
      libs = library_files;
      virtuals = virtual_files;
    }
  in
  List.map (fun file -> { env; file }) ml_files

let check_unit { env; file } =
  match
    check_file ~library_files:env.libs ~virtual_impl_files:env.virtuals
      ~files:env.files ~executable_modules:env.exes ~test_modules:env.tests file
  with
  | None -> []
  | Some issue -> [ issue ]

let check ctx = enumerate ctx |> List.concat_map check_unit

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
