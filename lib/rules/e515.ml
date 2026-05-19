(** E515: Tests and Libraries in Same Directory *)

type payload = { directory : string; library_name : string; test_name : string }

(** Check if a directory path looks like a test directory *)
let is_test_directory dir =
  let dir_lower = String.lowercase_ascii dir in
  Astring.String.is_infix ~affix:"/test/" dir_lower
  || Astring.String.is_infix ~affix:"/tests/" dir_lower
  || String.starts_with ~prefix:"test/" dir_lower
  || String.starts_with ~prefix:"tests/" dir_lower
  || dir_lower = "test" || dir_lower = "tests"

(** Check if a library name suggests it's a test support library *)
let is_test_support_library name =
  let name_lower = String.lowercase_ascii name in
  String.starts_with ~prefix:"test" name_lower

let check (ctx : Context.project) =
  (* Get directories containing non-test library files *)
  let lib_dirs =
    List.concat_map
      (fun lib ->
        (* Skip test support libraries *)
        let name = Project_index.Library.local_name lib in
        if is_test_support_library name then []
        else
          List.filter_map
            (fun file ->
              let dir = Fpath.parent file |> Fpath.to_string in
              (* Skip if this is already a test directory *)
              if is_test_directory dir then None else Some (dir, name))
            (Project_index.Library.files lib))
      (Project.Query.source_libraries (Context.index ctx))
  in

  (* Check if any test files are in the same directory as library files *)
  List.concat_map
    (fun test ->
      let test_name = Project_index.source_stanza_name test in
      List.filter_map
        (fun file ->
          let test_dir = Fpath.parent file |> Fpath.to_string in
          (* Find any library in the same directory *)
          match
            List.find_opt (fun (lib_dir, _) -> lib_dir = test_dir) lib_dirs
          with
          | Some (dir, lib_name) ->
              let loc =
                Location.v ~file:(Fpath.to_string file) ~start_line:1
                  ~start_col:0 ~end_line:1 ~end_col:0
              in
              Some
                (Issue.v ~loc
                   { directory = dir; library_name = lib_name; test_name })
          | None -> None)
        (Project_index.source_stanza_files test))
    (Context.test_stanzas ctx)

let pp ppf { directory; library_name; test_name } =
  Fmt.pf ppf
    "Test '%s' and library '%s' are in the same directory '%s' - move tests to \
     a separate test/ directory"
    test_name library_name directory

let rule =
  Rule.v ~code:"E515" ~title:"Tests and Libraries in Same Directory"
    ~category:Project_structure
    ~hint:
      "Libraries and tests should be in separate directories for clear project \
       structure. Put library code in lib/ and tests in test/. Using explicit \
       (modules ...) to co-locate them in the same directory is discouraged."
    ~examples:[] ~pp (Project check)
