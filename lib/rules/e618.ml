(** E618: Non-Test File in Test Stanza *)

type payload = {
  filename : string;
  test_stanza : string;
  prefix : string;
  file_count : int;
  conflicts_with_library : bool;
}

(** Guess the expected prefix by checking if any path segment is "fuzz".
    This handles both fuzz/foo.ml and fuzz/diff/foo.ml. *)
let prefix_of_dir file =
  if List.exists (String.equal "fuzz") (Fpath.segs file) then "fuzz_"
  else "test_"

let runner_of_prefix = function "fuzz_" -> "fuzz" | _ -> "test"

let is_valid basename ~prefix =
  String.starts_with ~prefix basename
  || String.equal basename (runner_of_prefix prefix)

let library_modules dune_describe (test_info : Dune.test_info) =
  let resolved =
    List.map (Dune.resolve_library dune_describe) test_info.libraries
  in
  let libs = Dune.libraries dune_describe in
  List.concat_map
    (fun lib_name ->
      List.filter_map
        (fun (lib : Dune.library_info) ->
          if String.equal lib.name lib_name then Some lib else None)
        libs)
    resolved
  |> List.concat_map (fun (lib : Dune.library_info) -> lib.files)
  |> List.filter_map (fun f ->
         if Fpath.has_ext ".ml" f then Some Fpath.(f |> rem_ext |> basename)
         else None)

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  List.concat_map
    (fun (test_info : Dune.test_info) ->
      let lib_modules = library_modules dune_describe test_info in
      List.filter_map
        (fun file ->
          if Fpath.has_ext ".ml" file then
            let basename = Fpath.(file |> rem_ext |> basename) in
            let prefix = prefix_of_dir file in
            if not (is_valid basename ~prefix) then
              let loc =
                Location.v ~file:(Fpath.to_string file) ~start_line:1
                  ~start_col:0 ~end_line:1 ~end_col:0
              in
              let file_count = List.length test_info.Dune.files in
              let conflicts_with_library =
                List.exists (String.equal basename) lib_modules
              in
              Some
                (Issue.v ~loc
                   {
                     filename = Fpath.to_string file;
                     test_stanza = test_info.Dune.name;
                     prefix;
                     file_count;
                     conflicts_with_library;
                   })
            else None
          else None)
        test_info.Dune.files)
    (Dune.tests dune_describe)

let pp ppf { filename; test_stanza; prefix; file_count; conflicts_with_library }
    =
  let basename = Filename.basename filename in
  let runner = runner_of_prefix prefix ^ ".ml" in
  if file_count = 1 then
    Fmt.pf ppf
      "File '%s' is the only file in test stanza '%s' - rename to %s" basename
      test_stanza runner
  else if conflicts_with_library then
    Fmt.pf ppf
      "File '%s' in test stanza '%s' conflicts with a module of the same name \
       in the tested library - rename to %s"
      basename test_stanza runner
  else
    Fmt.pf ppf
      "File '%s' in test stanza '%s' does not follow the %s naming convention \
       - rename to %s or move to a separate directory"
      basename test_stanza prefix runner

let rule =
  Rule.v ~code:"E618" ~title:"Non-Test File in Test Stanza" ~category:Testing
    ~hint:
      "All .ml files in a test stanza should follow the test_ (or fuzz_ in \
       fuzz/ directories) naming convention or be the test runner (test.ml). \
       Non-test modules should be renamed to the runner name or moved to a \
       separate directory."
    ~examples:[] ~pp (Project check)
