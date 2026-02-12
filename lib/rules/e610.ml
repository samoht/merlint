(** E610: Test Without Library *)

type payload = { test_file : string; expected_module : string }

(** Extract the relative path from test/ directory. e.g., "test/foo/test_x.ml"
    -> "foo/x.ml" "test/test_x.ml" -> "x.ml" *)
let expected_lib_path test_file =
  let path = Fpath.to_string test_file in
  (* Find "test/" in the path and extract what comes after *)
  match Astring.String.find_sub ~sub:"/test/" path with
  | Some idx ->
      let after_test =
        String.sub path (idx + 6) (String.length path - idx - 6)
      in
      (* Replace test_x.ml with x.ml *)
      let basename = Filename.basename after_test in
      let dirname = Filename.dirname after_test in
      if String.starts_with ~prefix:"test_" basename then
        let lib_basename = String.sub basename 5 (String.length basename - 5) in
        Some
          (if dirname = "." then lib_basename
           else Filename.concat dirname lib_basename)
      else None
  | None ->
      (* Fallback: just use basename *)
      let basename = Fpath.(test_file |> rem_ext |> basename) in
      if String.starts_with ~prefix:"test_" basename then
        Some (String.sub basename 5 (String.length basename - 5) ^ ".ml")
      else None

let check ctx =
  let dune_describe = Context.dune_describe ctx in

  (* Build a set of library module paths (relative to lib/) *)
  let library_module_paths =
    List.concat_map
      (fun (lib_info : Dune.library_info) ->
        List.filter_map
          (fun file ->
            if Fpath.has_ext ".ml" file then
              let path = Fpath.to_string file in
              (* Extract path relative to lib/ *)
              match Astring.String.find_sub ~sub:"/lib/" path with
              | Some idx ->
                  Some
                    (String.sub path (idx + 5) (String.length path - idx - 5))
              | None -> Some (Fpath.to_string file)
            else None)
          lib_info.files)
      (Dune.libraries dune_describe)
  in

  (* Check each test file *)
  let issues = ref [] in
  List.iter
    (fun test_info ->
      List.iter
        (fun file ->
          if Fpath.has_ext ".ml" file then
            let test_module = Fpath.(file |> rem_ext |> basename) in
            if String.starts_with ~prefix:"test_" test_module then
              match expected_lib_path file with
              | Some expected_path ->
                  let found = List.mem expected_path library_module_paths in
                  if not found then
                    let loc =
                      Location.v ~file:(Fpath.to_string file) ~start_line:1
                        ~start_col:0 ~end_line:1 ~end_col:0
                    in
                    issues :=
                      Issue.v ~loc
                        {
                          test_file = Fpath.to_string file;
                          expected_module = expected_path;
                        }
                      :: !issues
              | None -> ())
        test_info.Dune.files)
    (Dune.tests dune_describe);
  List.rev !issues

let pp ppf { test_file = _; expected_module } =
  Fmt.pf ppf "Test file exists but corresponding library module '%s' not found"
    expected_module

let rule =
  Rule.v ~code:"E610" ~title:"Test Without Library" ~category:Testing
    ~hint:
      "Every test module should have a corresponding library module. This \
       ensures that tests are testing actual library functionality rather than \
       testing code that doesn't exist in the library."
    ~examples:[] ~pp (Project check)
