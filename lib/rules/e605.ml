(** E605: Missing Test File *)

module Issue_location = Location
module String_set = Set.Make (String)

type payload = { module_name : string; expected_test_file : string }

let log_src = Logs.Src.create "merlint.rules.e605" ~doc:"E605 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

(** Compute the expected test file path for the module [module_name] that
    [source_file] belongs to. For [lib] and [src] source directories, the
    directory is replaced with [test]. For any other source directory, it is
    preserved under [test/]. The basename is the module's name prefixed with
    [test_], which is the file's own stem except where a stanza compiles it
    under another name. Subdirectories within the source dir are preserved.

    - [proj/lib/foo.ml] -> [proj/test/test_foo.ml]
    - [proj/src/foo.ml] -> [proj/test/test_foo.ml]
    - [proj/proto/foo.ml] -> [proj/test/proto/test_foo.ml]
    - [proj/lib/sub/bar.ml] -> [proj/test/sub/test_bar.ml]
    - [proj/foo/sub/bar.ml] -> [proj/test/foo/sub/test_bar.ml]
    - [proj/lib/pick.unix.ml] compiling as [pick] -> [proj/test/test_pick.ml] *)
let expected_test_path ~module_name source_file =
  let basename = "test_" ^ module_name ^ Filename.extension source_file in
  let parts = String.split_on_char '/' source_file in
  let rec find_lib_dir prefix = function
    | [] -> None
    | dir :: rest when dir = "lib" || dir = "src" ->
        Some (String.concat "/" (List.rev prefix), dir, rest)
    | part :: rest -> find_lib_dir (part :: prefix) rest
  in
  match find_lib_dir [] parts with
  | Some (project_prefix, _lib_or_src, rest) ->
      let dirname = Filename.dirname (String.concat "/" rest) in
      let test_after =
        if dirname = "." then basename else Filename.concat dirname basename
      in
      Fmt.str "%s/test/%s" project_prefix test_after
  | None ->
      let dir = Filename.dirname source_file in
      Filename.concat (Filename.concat dir "test") basename

let missing_test_issue module_name source_file =
  let loc =
    Issue_location.v ~file:source_file ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  Issue.v ~loc
    {
      module_name;
      expected_test_file = expected_test_path ~module_name source_file;
    }

let skipped_by_dir file_path =
  File.is_in_test_dir (Fpath.v file_path) || File.is_in_examples file_path

let test_scope_libraries idx =
  Project_index.unattributed_stanza_groups idx
  |> List.concat_map (fun (group : Project_index.unattributed_stanza_group) ->
      List.concat_map
        (fun (stanza : Project_index.unattributed_stanza) ->
          match stanza.kind with
          | Project_index.Test | Project_index.Fuzz -> stanza.libraries
          | Project_index.Mdx -> [])
        group.stanzas)
  |> String_set.of_list

(* One module, one issue: several files can carry the same module -- every
   branch of a [(select ...)] is a body of the target -- and the gap they report
   is the module's, not each file's. *)
let one_issue_per_module gaps =
  List.fold_left
    (fun (seen, issues) (m, path) ->
      if String_set.mem m seen then (seen, issues)
      else (String_set.add m seen, missing_test_issue m path :: issues))
    (String_set.empty, []) gaps
  |> snd |> List.rev

(* [file] belongs to a library some package-less test or fuzz stanza exercises,
   under either the name that stanza spells or the library's own local one. *)
let covered_by_test_scope idx scope file =
  Project_index.libraries_of_file idx file
  |> List.exists (fun lib ->
      String_set.mem (Project_index.Library.name lib) scope
      || String_set.mem (Project_index.Library.local_name lib) scope)

let check (ctx : Context.project) =
  let idx = Context.index ctx in
  let test_scope = test_scope_libraries idx in
  let private_modules =
    Project_index.private_module_names idx |> String_set.of_list
  in
  let test_modules =
    Project_index.test_module_names idx |> String_set.of_list
  in
  let selected = ctx.Context.in_analyze_set in
  let exempt_module file path m =
    String.starts_with ~prefix:"test_" m
    || File.is_unit_companion_module m
    || Project_index.is_generated_source_file idx file
    || String_set.mem m private_modules
    || skipped_by_dir path
    || String_set.mem ("test_" ^ m) test_modules
    || covered_by_test_scope idx test_scope file
  in
  let untested_module file =
    let path = Fpath.to_string file in
    if not (File_kind.is_ml path) then None
    else if not (selected (Context.resolve ctx file)) then None
    else
      (* The name the module reaches the build under, which is the file's own
         stem unless a stanza compiles it as something else: every branch of one
         [(select ...)] is a body of the target, so the gap is the target's. *)
      let m = Project_index.module_name_of_file idx file in
      if exempt_module file path m then None
      else
        (* Ask the index whether the expected test file exists, rather than
           stat-ing it: [Unindexed] (present on disk but not captured by a
           file-scoped scan) counts as present, only [Absent] is missing. *)
        match
          Project_index.source_presence idx
            (Fpath.v (expected_test_path ~module_name:m path))
        with
        | Project_index.Indexed | Project_index.Unindexed -> None
        | Project_index.Absent -> Some (m, path)
  in
  Project_index.public_library_source_files idx
  |> List.filter_map untested_module
  |> one_issue_per_module

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
