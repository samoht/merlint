(** E606: Test Files Mixed From Different Libraries *)

type payload = { test_module : string; library_name : string }

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in

  (* Build a map from module names to all libraries that contain them *)
  let module_to_libraries =
    List.fold_left
      (fun acc (lib_info : Dune.library_info) ->
        List.fold_left
          (fun acc file ->
            if Fpath.has_ext ".ml" file then
              let module_name = Fpath.(file |> rem_ext |> basename) in
              match List.assoc_opt module_name acc with
              | Some libs ->
                  (module_name, lib_info.name :: libs)
                  :: List.remove_assoc module_name acc
              | None -> (module_name, [ lib_info.name ]) :: acc
            else acc)
          acc lib_info.files)
      []
      (Dune.get_libraries dune_describe)
  in

  (* Build a map from public names to internal names for declared library resolution *)
  let public_to_internal =
    List.fold_left
      (fun acc (lib_info : Dune.library_info) ->
        match lib_info.public_name with
        | Some pub_name -> (pub_name, lib_info.name) :: acc
        | None -> acc)
      []
      (Dune.get_libraries dune_describe)
  in

  (* For each test stanza, find which libraries are tested *)
  let test_stanza_libraries =
    List.fold_left
      (fun acc test_info ->
        let test_file_libs =
          List.filter_map
            (fun file ->
              if Fpath.has_ext ".ml" file then
                let basename = Fpath.(file |> rem_ext |> basename) in
                if String.starts_with ~prefix:"test_" basename then
                  let tested_module =
                    String.sub basename 5 (String.length basename - 5)
                  in
                  match List.assoc_opt tested_module module_to_libraries with
                  | Some libs ->
                      (* Only include if module exists in exactly one library *)
                      if List.length libs = 1 then
                        let lib = List.hd libs in
                        Some (basename, lib, Fpath.to_string file)
                      else None (* Skip ambiguous modules *)
                  | None -> None
                else None
              else None)
            test_info.Dune.files
        in
        (test_info.Dune.name, test_file_libs, test_info.Dune.libraries) :: acc)
      []
      (Dune.get_tests dune_describe)
  in

  (* Check each test stanza to see if it mixes tests from different libraries *)
  let issues = ref [] in

  List.iter
    (fun (_, test_files, declared_libraries) ->
      (* If there are declared libraries, check that test files only test those *)
      if declared_libraries <> [] then
        (* Resolve declared libraries: map public names to internal names if needed *)
        let resolved_libraries =
          List.map
            (fun declared_lib ->
              match List.assoc_opt declared_lib public_to_internal with
              | Some internal_name -> internal_name
              | None -> declared_lib (* Already an internal name *))
            declared_libraries
        in
        List.iter
          (fun (test_module, lib_name, file_path) ->
            if not (List.mem lib_name resolved_libraries) then
              let loc =
                Location.create ~file:file_path ~start_line:1 ~start_col:0
                  ~end_line:1 ~end_col:0
              in
              issues :=
                Issue.v ~loc { test_module; library_name = lib_name } :: !issues)
          test_files
      else
        (* No declared libraries - skip this test stanza *)
        ())
    test_stanza_libraries;

  !issues

let pp ppf { test_module; library_name } =
  Fmt.pf ppf
    "Test file '%s.ml' tests library '%s' which is not explicitly declared in \
     the test's dune file"
    test_module library_name

let rule =
  Rule.v ~code:"E606" ~title:"Test File in Wrong Directory" ~category:Testing
    ~hint:
      "Test files for different libraries should not be mixed in the same test \
       directory. Organize test files so that each test directory contains \
       tests for only one library to maintain clear test organization."
    ~examples:
      [
        Example.bad Examples.E606.Bad.test_utils_ml;
        Example.good Examples.E606.Good.parser_ml;
      ]
    ~pp (Project check)
