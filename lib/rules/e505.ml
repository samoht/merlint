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

(* Memoised "is this directory the source of a virtual-implementation
   library?" predicate, scoped to a single rule run. The answer lives in
   the project index; we only memoise the directory-to-library lookup. *)
let module_name_matches a b =
  String.equal (String.lowercase_ascii a) (String.lowercase_ascii b)

let library_owns_module module_name lib =
  match Dune.File.Library.modules lib with
  | All_standard -> true
  | Only modules -> List.exists (module_name_matches module_name) modules
  | Standard_except excluded ->
      not (List.exists (module_name_matches module_name) excluded)

let dune_file_virtual_impl_check =
  let cache = Hashtbl.create 32 in
  fun dir module_name ->
    let key = (dir, module_name) in
    match Hashtbl.find_opt cache key with
    | Some v -> v
    | None ->
        let v =
          let dune_file = Filename.concat dir "dune" in
          match Dune.File.of_file dune_file with
          | Error _ -> false
          | Ok dune ->
              Dune.File.libraries dune
              |> List.exists (fun lib ->
                  Dune.File.Library.implements lib <> None
                  && library_owns_module module_name lib)
        in
        Hashtbl.replace cache key v;
        v

let dir_is_virtual_impl_check index =
  let cache = Hashtbl.create 32 in
  fun dir ->
    match Hashtbl.find_opt cache dir with
    | Some v -> v
    | None ->
        let v =
          match Project_index.library_in_dir index (Fpath.v dir) with
          | None -> false
          | Some lib -> Project_index.Library.is_virtual_implementation lib
        in
        Hashtbl.replace cache dir v;
        v

let is_virtual_impl_file is_virtual_dir ml_file =
  let dir = Filename.dirname ml_file in
  let module_name = Filename.basename (Filename.remove_extension ml_file) in
  is_virtual_dir dir || dune_file_virtual_impl_check dir module_name

let missing_mli_issue files ml_file =
  let mli_path = Filename.remove_extension ml_file ^ ".mli" in
  if List.mem mli_path files then None
  else
    let loc =
      Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    in
    Some (Issue.v ~loc { ml_file; expected_mli = mli_path })

let check_file ~is_virtual_dir ~files ~executable_modules ~test_modules ml_file
    =
  if not (File_kind.is_ml ml_file) then None
  else if should_skip_module ~executable_modules ~test_modules ml_file then None
  else if is_virtual_impl_file is_virtual_dir ml_file then None
  else missing_mli_issue files ml_file

let check (ctx : Context.project) =
  let files = Context.analyze_set ctx in
  let executable_modules = Context.executable_modules ctx in
  let test_modules = Context.test_modules ctx in
  let is_virtual_dir = dir_is_virtual_impl_check (Context.index ctx) in
  List.filter_map
    (check_file ~is_virtual_dir ~files ~executable_modules ~test_modules)
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
