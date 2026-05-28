(** E505: Missing MLI File *)

type payload = { ml_file : string; expected_mli : string }

let log_src = Logs.Src.create "merlint.rules.e505" ~doc:"E505 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)
module String_set = Set.Make (String)

module Path_set = Set.Make (struct
  type t = Context.path

  let compare = Context.Path.compare
end)

type env = {
  index : Project_index.t;
  exes : String_set.t;
  tests : String_set.t;
  libs : Path_set.t;
  virtuals : Path_set.t;
}

type work = { env : env; file : Context.path }

let string_set xs =
  List.fold_left (fun acc x -> String_set.add x acc) String_set.empty xs

let path_set xs =
  List.fold_left (fun acc x -> Path_set.add x acc) Path_set.empty xs

let is_test_module module_name module_name_capitalized test_modules =
  String_set.mem module_name test_modules
  || String_set.mem module_name_capitalized test_modules
  || String.starts_with ~prefix:"test_" module_name

let should_skip_module ~executable_modules ~test_modules ml_file =
  let module_name =
    Fpath.(Context.fpath_of_path ml_file |> rem_ext |> basename)
  in
  let module_name_capitalized = String.capitalize_ascii module_name in
  let is_exe = String_set.mem module_name_capitalized executable_modules in
  let is_test =
    is_test_module module_name module_name_capitalized test_modules
  in
  let is_companion = File.is_unit_companion_module module_name in
  if is_exe then
    Log.debug (fun m ->
        m "File %a is executable (module %s)" Context.Path.pp ml_file
          module_name_capitalized);
  if is_test then
    Log.debug (fun m ->
        m "File %a is test module (module %s)" Context.Path.pp ml_file
          module_name);
  if is_companion then
    Log.debug (fun m ->
        m "File %a is unit companion module" Context.Path.pp ml_file);
  is_exe || is_test || is_companion

let is_library_file index file =
  let file = Context.fpath_of_path file in
  Project_index.libraries_of_file index file <> []
  || Project_index.has_library_stanza_in_dir index (Fpath.parent file)

let is_virtual_impl_file index file =
  let file = Context.fpath_of_path file in
  Project_index.libraries_of_file index file
  |> List.exists Project_index.Library.is_virtual_implementation

let missing_mli_issue index ml_file =
  let mli_path = Context.Path.(ml_file |> rem_ext |> add_ext ".mli") in
  (* Classify with the index rather than stat-ing the filesystem: [Unindexed]
     means the .mli is on disk but escaped indexing (e.g. a file-scoped scan
     under --no-build), so only [Absent] is a genuinely missing interface. *)
  match
    Project_index.source_presence index (Context.fpath_of_path mli_path)
  with
  | Project_index.Indexed | Project_index.Unindexed -> None
  | Project_index.Absent ->
      let ml_file = Context.string_of_path ml_file in
      let expected_mli = Context.string_of_path mli_path in
      let loc =
        Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1
          ~end_col:0
      in
      Some (Issue.v ~loc { ml_file; expected_mli })

let check_file ~library_files ~virtual_impl_files ~index ~executable_modules
    ~test_modules ml_file =
  if not (Context.Path.has_ext ".ml" ml_file) then None
  else if not (Path_set.mem ml_file library_files) then None
  else
    let module_name = Context.Path.(ml_file |> rem_ext |> basename) in
    let is_companion = File.is_unit_companion_module module_name in
    if is_companion then None
    else if should_skip_module ~executable_modules ~test_modules ml_file then
      (* For a library-owned module, only executable ownership should suppress
         E505. Test-shaped names such as [test_helpers] still need interfaces
         when dune metadata says they belong to a library. *)
      let module_name_capitalized = String.capitalize_ascii module_name in
      if String_set.mem module_name_capitalized executable_modules then None
      else missing_mli_issue index ml_file
    else if Path_set.mem ml_file virtual_impl_files then None
    else missing_mli_issue index ml_file

let enumerate ctx =
  let files = Context.analyze_set ctx in
  let ml_files = List.filter (Context.Path.has_ext ".ml") files in
  let executable_modules = Context.executable_modules ctx in
  let test_modules = Context.test_modules ctx in
  let index = Context.index ctx in
  let library_files =
    List.filter (is_library_file index) ml_files |> path_set
  in
  let virtual_files =
    List.filter (is_virtual_impl_file index) ml_files |> path_set
  in
  let env =
    {
      index;
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
      ~index:env.index ~executable_modules:env.exes ~test_modules:env.tests file
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
