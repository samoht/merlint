(** E606: Test Files Mixed From Different Libraries *)

type payload = {
  test_module : string;
  library_name : string;
  mixed_with : string list; (* Other libraries in same test directory *)
}

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in

  (* Build a map from module names to all libraries that contain them *)
  let module_to_libraries =
    List.fold_left
      (fun acc (lib_name, files) ->
        List.fold_left
          (fun acc file ->
            if Fpath.has_ext ".ml" file then
              let module_name = Fpath.(file |> rem_ext |> basename) in
              match List.assoc_opt module_name acc with
              | Some libs ->
                  (module_name, lib_name :: libs)
                  :: List.remove_assoc module_name acc
              | None -> (module_name, [ lib_name ]) :: acc
            else acc)
          acc files)
      []
      (Dune.get_libraries dune_describe)
  in

  (* For each test stanza, find which libraries are tested *)
  let test_stanza_libraries =
    List.fold_left
      (fun acc (test_name, files) ->
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
                        Some (basename, List.hd libs, Fpath.to_string file)
                      else None (* Skip ambiguous modules *)
                  | None -> None
                else None
              else None)
            files
        in
        (test_name, test_file_libs) :: acc)
      []
      (Dune.get_tests dune_describe)
  in

  (* Check each test stanza to see if it mixes tests from different libraries *)
  let issues = ref [] in

  List.iter
    (fun (_, test_files) ->
      (* Get unique libraries in this test stanza *)
      let libraries_in_stanza =
        test_files
        |> List.map (fun (_, lib, _) -> lib)
        |> List.sort_uniq String.compare
      in

      (* If more than one library is tested in this stanza, flag each test file *)
      if List.length libraries_in_stanza > 1 then
        List.iter
          (fun (test_module, lib_name, file_path) ->
            let other_libs =
              test_files
              |> List.filter_map (fun (_, lib, _) ->
                     if lib <> lib_name then Some lib else None)
              |> List.sort_uniq String.compare
            in
            let loc =
              Location.create ~file:file_path ~start_line:1 ~start_col:0
                ~end_line:1 ~end_col:0
            in
            issues :=
              Issue.v ~loc
                {
                  test_module;
                  library_name = lib_name;
                  mixed_with = other_libs;
                }
              :: !issues)
          test_files)
    test_stanza_libraries;

  !issues

let pp ppf { test_module; library_name; mixed_with } =
  Fmt.pf ppf
    "Test file '%s.ml' tests library '%s' but is mixed with tests for %s"
    test_module library_name
    (match mixed_with with
    | [] -> "other libraries"
    | [ other ] -> Fmt.str "library '%s'" other
    | others ->
        Fmt.str "libraries %s"
          (String.concat ", " (List.map (fun l -> "'" ^ l ^ "'") others)))

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
