(** E605: Missing Test File *)

module Issue_location = Location
module String_set = Set.Make (String)

type payload = { module_name : string; expected_test_file : string }

let log_src = Logs.Src.create "merlint.rules.e605" ~doc:"E605 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

(** Compute expected test file path from source file. For [lib] and [src] source
    directories, the directory is replaced with [test]. For any other source
    directory, it is preserved under [test/]. The basename is always prefixed
    with [test_]. Subdirectories within the source dir are preserved.

    - [proj/lib/foo.ml] -> [proj/test/test_foo.ml]
    - [proj/src/foo.ml] -> [proj/test/test_foo.ml]
    - [proj/proto/foo.ml] -> [proj/test/proto/test_foo.ml]
    - [proj/lib/sub/bar.ml] -> [proj/test/sub/test_bar.ml]
    - [proj/foo/sub/bar.ml] -> [proj/test/foo/sub/test_bar.ml] *)
let expected_test_path source_file =
  let parts = String.split_on_char '/' source_file in
  let rec find_lib_dir prefix = function
    | [] -> None
    | dir :: rest when dir = "lib" || dir = "src" ->
        Some (String.concat "/" (List.rev prefix), dir, rest)
    | part :: rest -> find_lib_dir (part :: prefix) rest
  in
  match find_lib_dir [] parts with
  | Some (project_prefix, _lib_or_src, rest) ->
      let after = String.concat "/" rest in
      let dirname = Filename.dirname after in
      let basename = Filename.basename after |> String.lowercase_ascii in
      let test_name = "test_" ^ basename in
      let test_after =
        if dirname = "." then test_name else Filename.concat dirname test_name
      in
      Fmt.str "%s/test/%s" project_prefix test_after
  | None ->
      let dir = Filename.dirname source_file in
      let base = Filename.basename source_file in
      Filename.concat (Filename.concat dir "test") ("test_" ^ base)

let missing_test_issue module_name source_file =
  let loc =
    Issue_location.v ~file:source_file ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  Issue.v ~loc
    { module_name; expected_test_file = expected_test_path source_file }

let module_name_of_path file =
  Fpath.basename file |> Filename.remove_extension |> String.lowercase_ascii

let skipped_by_dir file_path =
  File.is_in_test_dir (Fpath.v file_path) || File.is_in_examples file_path

let check (ctx : Context.project) =
  let idx = Context.index ctx in
  let private_modules =
    Project_index.private_module_names idx |> String_set.of_list
  in
  let test_modules =
    Project_index.test_module_names idx |> String_set.of_list
  in
  let selected = ctx.Context.in_analyze_set in
  let needs_test file =
    let path = Fpath.to_string file in
    if not (File_kind.is_ml path) then None
    else if not (selected path) then None
    else
      let m = module_name_of_path file in
      if String.starts_with ~prefix:"test_" m then None
      else if File.is_unit_companion_module m then None
      else if String_set.mem m private_modules then None
      else if skipped_by_dir path then None
      else if String_set.mem ("test_" ^ m) test_modules then None
      else if Sys.file_exists (expected_test_path path) then None
      else Some (missing_test_issue m path)
  in
  Project_index.public_library_source_files idx |> List.filter_map needs_test

let pp ppf { module_name; expected_test_file } =
  Fmt.pf ppf
    "Module '%s' has no tests yet — write thoughtful, adversarial tests \
     against it. Expected file: %s"
    module_name expected_test_file

let rule =
  Rule.v ~code:"E605" ~title:"Untested module — write tests for it"
    ~category:Testing
    ~hint:
      "This rule is not a checkbox exercise. The goal is real test coverage \
       and real code quality, not a [test_<module>.ml] file that satisfies the \
       linter. Treat each untested module as an opportunity: write the tests \
       you'd want a reviewer to write before you trusted the code in \
       production. Anchor on the spec when one exists -- cite section numbers, \
       copy test vectors verbatim. Probe the edge cases the implementation \
       hopes you won't try: empty / single-element / maximum-length inputs, \
       NaN, malformed UTF-8, negative sizes, off-by-one boundaries, integer \
       overflow. Drive at least one hostile case (random bytes, truncated \
       payloads, malicious lengths); the public API should fail with a clear \
       error, not crash or corrupt state. Use exact expected values, not loose \
       ranges. A trivial module still deserves the exercise -- writing the \
       tests usually surfaces the corner the author didn't think through."
    ~examples:[] ~pp (Project check)
