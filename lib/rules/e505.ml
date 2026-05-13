(** E505: Missing MLI File *)

type payload = { ml_file : string; expected_mli : string }

let log_src = Logs.Src.create "merlint.rules.e505" ~doc:"E505 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

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
      || String.starts_with ~prefix:"test_" module_name
    in

    (* Skip if it's an interface definition file *_intf.ml *)
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
  in

  (* A virtual-module implementation lives in a library declared
     [(implements <virt>)]. The interface is the abstract [.mli] alongside the
     virtual library; dune forbids the implementation from carrying its own
     [.mli]. Detect this by checking the closest dune file. *)
  let implements_re =
    Re.compile (Re.seq [ Re.str "(implements"; Re.set " \t\n" ])
  in
  let is_virtual_impl ml_file =
    let dir = Filename.dirname ml_file in
    let dune_path = Filename.concat dir "dune" in
    match In_channel.with_open_text dune_path In_channel.input_all with
    | exception _ -> false
    | content -> Re.execp implements_re content
  in

  (* For each ML file being analyzed, check if it has a corresponding MLI file *)
  List.filter_map
    (fun ml_file ->
      if String.ends_with ~suffix:".ml" ml_file then
        (* Only check for .mli files for library modules, not executables or test modules *)
        if (not (should_skip_module ml_file)) && not (is_virtual_impl ml_file)
        then
          let base_name = Filename.remove_extension ml_file in
          let mli_path = base_name ^ ".mli" in
          (* Check if the MLI file exists in the list of project files *)
          if not (List.mem mli_path files) then
            let loc =
              Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1
                ~end_col:0
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
