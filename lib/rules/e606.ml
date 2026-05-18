(** E606: Test Files Mixed From Different Libraries *)

type payload = { test_module : string; library_name : string }

let ml_module file =
  if Fpath.has_ext ".ml" file then Some Fpath.(file |> rem_ext |> basename)
  else None

let issue_for_file mod_to_libs resolved file =
  match ml_module file with
  | None -> None
  | Some basename -> (
      match Dune_describe.test_file_library mod_to_libs basename with
      | Some lib when not (List.mem lib resolved) ->
          let loc =
            Location.v ~file:(Fpath.to_string file) ~start_line:1 ~start_col:0
              ~end_line:1 ~end_col:0
          in
          Some (Issue.v ~loc { test_module = basename; library_name = lib })
      | _ -> None)

let check_test_info dune_describe mod_to_libs
    (test_info : Dune_describe.test_info) =
  if test_info.libraries = [] then []
  else
    let resolved =
      List.map (Dune_describe.resolve_library dune_describe) test_info.libraries
    in
    List.filter_map (issue_for_file mod_to_libs resolved) test_info.files

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let mod_to_libs = Dune_describe.libraries_of_module dune_describe in
  Dune_describe.tests dune_describe
  |> List.concat_map (check_test_info dune_describe mod_to_libs)

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
