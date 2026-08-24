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

(* The subject is where the two stanzas are *declared*, which is the directory
   holding their dune file and not the directory each of their sources happens
   to sit in. The two part company whenever a stanza imports a source from
   elsewhere -- a [(copy_files ../lib/shared.ml)] compiles lib/shared.ml as a
   module of a test declared in test/ -- and reading the file's parent as the
   stanza's directory then reports a test and a library sharing lib/ when they
   share nothing. *)
let check (ctx : Context.project) =
  (* Directories declaring a non-test library *)
  let lib_dirs =
    List.filter_map
      (fun lib ->
        let name = Project_index.Library.local_name lib in
        if is_test_support_library name then None
        else
          match Project_index.Library.source_dir lib with
          | None -> None
          | Some dir ->
              let dir = Context.resolve ctx dir in
              let rel_dir = Context.project_relative_path ctx dir in
              (* Skip if this is already a test directory *)
              if is_test_directory rel_dir then None else Some (dir, name))
      (Project.Query.source_libraries (Context.index ctx))
  in

  (* Check whether any test stanza is declared in one of them *)
  List.concat_map
    (fun (test : Project_index.source_stanza) ->
      let test_name = test.name in
      let test_dir = Context.resolve ctx test.dir in
      match
        List.find_opt
          (fun (lib_dir, _) -> Path.compare lib_dir test_dir = 0)
          lib_dirs
      with
      | None -> []
      | Some (dir, lib_name) ->
          let directory = Path.dir_display dir in
          test.files
          |> List.filter_map (fun file ->
              let file = Context.resolve ctx file in
              if Path.compare (Path.parent file) test_dir <> 0 then None
              else
                let loc =
                  Location.v
                    ~file:(Context.string_of_path file)
                    ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
                in
                Some
                  (Issue.v ~loc
                     { directory; library_name = lib_name; test_name })))
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
