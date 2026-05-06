(** E606: Test Files Mixed From Different Libraries *)

type payload = { test_module : string; library_name : string }

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let mod_to_libs = Dune.libraries_of_module dune_describe in
  let issues = ref [] in
  List.iter
    (fun (test_info : Dune.test_info) ->
      if test_info.libraries <> [] then
        let resolved =
          List.map (Dune.resolve_library dune_describe) test_info.libraries
        in
        List.iter
          (fun file ->
            if Fpath.has_ext ".ml" file then
              let basename = Fpath.(file |> rem_ext |> basename) in
              match Dune.test_file_library mod_to_libs basename with
              | Some lib when not (List.mem lib resolved) ->
                  let loc =
                    Location.v ~file:(Fpath.to_string file) ~start_line:1
                      ~start_col:0 ~end_line:1 ~end_col:0
                  in
                  issues :=
                    Issue.v ~loc { test_module = basename; library_name = lib }
                    :: !issues
              | _ -> ())
          test_info.files)
    (Dune.tests dune_describe);
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
