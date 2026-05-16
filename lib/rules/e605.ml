(** E605: Missing Test File *)

module Issue_location = Location
open Ocaml_parsing

type payload = { module_name : string; expected_test_file : string }

let log_src = Logs.Src.create "merlint.rules.e605" ~doc:"E605 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

(** Check if a module only contains type definitions, module aliases, and
    delegations. This detects facade/wrapper modules that just re-export other
    modules (e.g. the top-level [Irmin] module). *)
let contains_only_types_and_modules ctx file_path =
  match File_view.parsetree (Context.file_view ctx file_path) with
  | None -> false
  | Some structure ->
      let rec is_facade_mod_expr (me : Parsetree.module_expr) =
        match me.pmod_desc with
        | Pmod_ident _ -> true (* module M = OtherModule *)
        | Pmod_apply _ -> true (* module M = Map.Make(String) *)
        | Pmod_structure items -> List.for_all is_facade_item items
        | Pmod_constraint (me, _) -> is_facade_mod_expr me
        | Pmod_functor (_, body) -> is_facade_mod_expr body
        | _ -> false
      and is_facade_item (item : Parsetree.structure_item) =
        match item.pstr_desc with
        | Pstr_type _ | Pstr_typext _ | Pstr_modtype _ | Pstr_open _
        | Pstr_include _ | Pstr_attribute _ ->
            true
        | Pstr_module { pmb_expr; _ } -> is_facade_mod_expr pmb_expr
        | Pstr_value (_, bindings) ->
            (* Accept simple delegations: let f = Other.f *)
            List.for_all
              (fun (vb : Parsetree.value_binding) ->
                match vb.pvb_expr.pexp_desc with
                | Pexp_ident _ -> true
                | _ -> false)
              bindings
        | _ -> false
      in
      List.for_all is_facade_item structure
  | exception Context.Analysis_error _ ->
      false (* If we can't parse, assume it needs tests *)

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
  (* Find the first [lib] or [src] component and split the path there.
     Everything before it is the project prefix; everything after is the
     module path within the library. The test file mirrors that structure
     under [test/].

     - [proj/lib/foo.ml] → [proj/test/test_foo.ml]
     - [proj/atp/lib/atp_mst.ml] → [proj/atp/test/test_atp_mst.ml]
     - [proj/lib/sub/bar.ml] → [proj/test/sub/test_bar.ml] *)
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

(** Creates a missing test file issue for a library module without corresponding
    test *)
let missing_test_issue module_name source_file =
  let loc =
    Issue_location.v ~file:source_file ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  let expected_path = expected_test_path source_file in
  Issue.v ~loc { module_name; expected_test_file = expected_path }

(** Build a set of file paths that belong to libraries. *)
let library_file_set dune_desc =
  Dune_describe.libraries dune_desc
  |> List.concat_map (fun (lib : Dune_describe.library_info) -> lib.files)
  |> List.map (fun p -> String.lowercase_ascii (Fpath.to_string p))

(** Collect the union of module names listed in [(private_modules ...)] across
    all libraries. Private modules are not exposed outside their library, so
    they cannot be referenced from a [test_<module>.ml] in a sibling test
    stanza, and should not be required to have a test file. *)
let private_module_set dune_desc =
  Dune_describe.libraries dune_desc
  |> List.concat_map (fun (lib : Dune_describe.library_info) ->
      lib.private_modules)
  |> List.map String.lowercase_ascii
  |> List.sort_uniq String.compare

(** Build a set of file paths that belong to executables. *)
let executable_file_set dune_desc =
  Dune_describe.executables dune_desc
  |> List.concat_map snd
  |> List.map (fun p -> String.lowercase_ascii (Fpath.to_string p))

let module_source_name file = Filename.basename (Filename.remove_extension file)

let source_matches_module lib_mod file =
  String.ends_with ~suffix:".ml" file && module_source_name file = lib_mod

let find_lib_source ~files ~lib_files ~exec_files lib_mod =
  let matches = List.filter (source_matches_module lib_mod) files in
  match
    List.find_opt
      (fun file -> List.mem (String.lowercase_ascii file) lib_files)
      matches
  with
  | Some _ as found -> found
  | None ->
      List.find_opt
        (fun file -> not (List.mem (String.lowercase_ascii file) exec_files))
        matches

let is_test_source file =
  String.ends_with ~suffix:".ml" file
  &&
  let basename = module_source_name file in
  String.starts_with ~prefix:"test_" basename || basename = "test"

let log_test_sources files lib_modules =
  let test_files = List.filter is_test_source files in
  Log.debug (fun m ->
      m "E605: Test .ml files in analyzed files: %d" (List.length test_files));
  List.iter (fun f -> Log.debug (fun m -> m "E605:   - %s" f)) test_files;
  if List.length test_files = 0 && List.length lib_modules > 0 then
    Log.debug (fun m ->
        m
          "E605: No test files found in analyzed files. Make sure to include \
           test directories in the analysis (e.g., 'merlint lib test' instead \
           of just 'merlint lib')")

let log_project_summary ~files ~lib_modules ~test_modules =
  Log.debug (fun m ->
      m "E605: Checking %d library modules" (List.length lib_modules));
  Log.debug (fun m ->
      m "E605: Found %d test modules in dune" (List.length test_modules));
  Log.debug (fun m ->
      m "E605: Test modules: %a" Fmt.(list ~sep:comma string) test_modules);
  Log.debug (fun m -> m "E605: Analyzing %d files" (List.length files));
  log_test_sources files lib_modules

let skipped_module_reason ctx file_path =
  if Astring.String.is_infix ~affix:"/test/" file_path then
    Some "defined in test directory"
  else if File.is_in_examples file_path then
    Some "defined in examples directory"
  else if contains_only_types_and_modules ctx file_path then
    Some "contains only types/modules"
  else None

let expected_test_name lib_mod = "test_" ^ String.lowercase_ascii lib_mod

let test_presence ~files ~test_modules expected =
  let in_dune = List.mem expected test_modules in
  let in_files =
    List.exists
      (fun file ->
        String.ends_with ~suffix:".ml" file
        && String.lowercase_ascii (module_source_name file) = expected)
      files
  in
  (in_dune, in_files)

let log_skip lib_mod reason =
  Log.debug (fun m -> m "E605: Skipping module '%s' (%s)" lib_mod reason)

let should_skip_module private_modules lib_mod =
  if String.starts_with ~prefix:"test_" lib_mod then None
  else if List.mem (String.lowercase_ascii lib_mod) private_modules then
    Some "listed in private_modules"
  else None

let source_candidate ctx ~files ~lib_files ~exec_files lib_mod =
  match find_lib_source ~files ~lib_files ~exec_files lib_mod with
  | None -> `Missing_source
  | Some file_path -> (
      match skipped_module_reason ctx file_path with
      | Some reason ->
          log_skip lib_mod reason;
          `Skipped_source
      | None -> `Source file_path)

let tests_missing ~files ~test_modules lib_mod =
  let expected = expected_test_name lib_mod in
  let in_dune, in_files = test_presence ~files ~test_modules expected in
  Log.debug (fun m ->
      m "E605: Checking %s -> %s (in_dune=%b, in_files=%b)" lib_mod expected
        in_dune in_files);
  (not in_dune) && not in_files

let missing_test_candidate ctx ~files ~lib_files ~exec_files ~private_modules
    ~test_modules lib_mod =
  match should_skip_module private_modules lib_mod with
  | Some reason ->
      log_skip lib_mod reason;
      None
  | None -> (
      match source_candidate ctx ~files ~lib_files ~exec_files lib_mod with
      | `Missing_source ->
          log_skip lib_mod "no library source file, only in executables";
          None
      | `Skipped_source -> None
      | `Source file_path ->
          if tests_missing ~files ~test_modules lib_mod then
            Some (lib_mod, file_path)
          else None)

let check (ctx : Context.project) =
  let files = Context.all_files ctx in
  let lib_modules = Context.lib_modules ctx in
  let test_modules = Context.test_modules ctx in
  let dune_desc = Context.dune_describe ctx in
  let lib_files = library_file_set dune_desc in
  let exec_files = executable_file_set dune_desc in
  let private_modules = private_module_set dune_desc in
  let test_modules = List.map String.lowercase_ascii test_modules in
  log_project_summary ~files ~lib_modules ~test_modules;
  lib_modules
  |> List.filter_map
       (missing_test_candidate ctx ~files ~lib_files ~exec_files
          ~private_modules ~test_modules)
  |> List.map (fun (m, source_file) -> missing_test_issue m source_file)

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
