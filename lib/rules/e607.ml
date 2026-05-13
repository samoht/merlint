(** E607: Test Stanza Mixes Multiple Libraries *)

type payload = { test_module : string; library_name : string }

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let mod_to_libs = Dune_describe.libraries_of_module dune_describe in
  let issues = ref [] in
  List.iter
    (fun (test_info : Dune_describe.test_info) ->
      if test_info.libraries = [] then
        (* No declared deps: check if test files span multiple libraries *)
        let file_libs =
          List.filter_map
            (fun file ->
              if Fpath.has_ext ".ml" file then
                let basename = Fpath.(file |> rem_ext |> basename) in
                Dune_describe.test_file_library mod_to_libs basename
              else None)
            test_info.files
        in
        let unique_libs = List.sort_uniq String.compare file_libs in
        if List.length unique_libs > 1 then
          (* Flag all test files whose library differs from the first one *)
          let primary_lib = List.hd unique_libs in
          List.iter
            (fun file ->
              if Fpath.has_ext ".ml" file then
                let basename = Fpath.(file |> rem_ext |> basename) in
                match Dune_describe.test_file_library mod_to_libs basename with
                | Some lib when lib <> primary_lib ->
                    let loc =
                      Location.v ~file:(Fpath.to_string file) ~start_line:1
                        ~start_col:0 ~end_line:1 ~end_col:0
                    in
                    issues :=
                      Issue.v ~loc
                        { test_module = basename; library_name = lib }
                      :: !issues
                | _ -> ())
            test_info.files)
    (Dune_describe.tests dune_describe);
  !issues

let pp ppf { test_module; library_name } =
  Fmt.pf ppf
    "Test file '%s.ml' tests library '%s' but test stanza has no declared \
     dependencies and mixes multiple libraries"
    test_module library_name

let rule =
  Rule.v ~code:"E607" ~title:"Test Stanza Mixes Multiple Libraries"
    ~category:Testing
    ~hint:
      "Test stanzas without declared library dependencies should not contain \
       test files for multiple different libraries. Split tests into separate \
       test stanzas, one per library."
    ~examples:[] ~pp (Project check)
