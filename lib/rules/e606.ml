(** E606: Test Files Mixed From Different Libraries *)

type payload = {
  test_module : string;
  library_name : string;
  mixed_with : string list; (* Other libraries in same test directory *)
}

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in

  (* Build a map from module names to their library *)
  let module_to_library =
    List.fold_left
      (fun acc (lib_name, files) ->
        List.fold_left
          (fun acc file ->
            if Fpath.has_ext ".ml" file then
              let module_name = Fpath.(file |> rem_ext |> basename) in
              (module_name, lib_name) :: acc
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
                  match List.assoc_opt tested_module module_to_library with
                  | Some lib -> Some (basename, lib, Fpath.to_string file)
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
              List.filter (fun l -> l <> lib_name) libraries_in_stanza
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

let pp ppf { test_module; library_name; mixed_with = _ } =
  Fmt.pf ppf
    "Test file '%s.ml' should be moved to a '%s' test directory since it tests \
     the '%s' library"
    test_module library_name library_name

let rule =
  Rule.v ~code:"E606" ~title:"Test File in Wrong Directory" ~category:Testing
    ~hint:
      "Organize test files to match your library structure. Create separate \
       test directories for each library (e.g., test/core/ for core library, \
       test/views/ for views library) and move test files to their \
       corresponding directories."
    ~examples:
      [
        Example.bad Examples.E606.Bad.test_utils_ml;
        Example.good Examples.E606.Good.parser_ml;
      ]
    ~pp (Project check)
