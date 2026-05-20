(** E607: Test Stanza Mixes Multiple Libraries *)

type payload = { test_module : string; library_name : string }

let ml_module file =
  if Fpath.has_ext ".ml" file then Some Fpath.(file |> rem_ext |> basename)
  else None

let library_for_file mod_to_libs file =
  Option.bind (ml_module file) (Project.Query.test_file_library mod_to_libs)

let issue_for_non_primary mod_to_libs primary_lib file =
  match (ml_module file, library_for_file mod_to_libs file) with
  | Some basename, Some lib when lib <> primary_lib ->
      let loc =
        Location.v ~file:(Fpath.to_string file) ~start_line:1 ~start_col:0
          ~end_line:1 ~end_col:0
      in
      Some (Issue.v ~loc { test_module = basename; library_name = lib })
  | _ -> None

let check_test_info mod_to_libs (test_stanza : Project_index.source_stanza) =
  let files = test_stanza.files in
  if test_stanza.libraries <> [] then []
  else
    let unique_libs =
      List.filter_map (library_for_file mod_to_libs) files
      |> List.sort_uniq String.compare
    in
    match unique_libs with
    | primary_lib :: _ :: _ ->
        List.filter_map (issue_for_non_primary mod_to_libs primary_lib) files
    | _ -> []

let check (ctx : Context.project) =
  let mod_to_libs = Project.Query.library_module_map (Context.index ctx) in
  Context.test_stanzas ctx |> List.concat_map (check_test_info mod_to_libs)

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
