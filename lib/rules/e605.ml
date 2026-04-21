(** E605: Missing Test File *)

type payload = { module_name : string; expected_test_file : string }

(** Check if a module only contains type definitions, module aliases, and
    delegations. This detects facade/wrapper modules that just re-export other
    modules (e.g. the top-level [Irmin] module). *)
let contains_only_types_and_modules file_path =
  try
    let ic = open_in file_path in
    let lexbuf = Lexing.from_channel ic in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = file_path };
    let structure = Parse.implementation lexbuf in
    close_in ic;

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
  with _ -> false (* If we can't parse, assume it needs tests *)

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
let create_missing_test_issue module_name source_file =
  let loc =
    Location.v ~file:source_file ~start_line:1 ~start_col:0 ~end_line:1
      ~end_col:0
  in
  let expected_path = expected_test_path source_file in
  Issue.v ~loc { module_name; expected_test_file = expected_path }

(** Build a set of file paths that belong to libraries. *)
let library_file_set dune_desc =
  Dune.libraries dune_desc
  |> List.concat_map (fun (lib : Dune.library_info) -> lib.files)
  |> List.map (fun p -> String.lowercase_ascii (Fpath.to_string p))

(** Collect the union of module names listed in [(private_modules ...)] across
    all libraries. Private modules are not exposed outside their library, so
    they cannot be referenced from a [test_<module>.ml] in a sibling test
    stanza, and should not be required to have a test file. *)
let private_module_set dune_desc =
  Dune.libraries dune_desc
  |> List.concat_map (fun (lib : Dune.library_info) -> lib.private_modules)
  |> List.map String.lowercase_ascii
  |> List.sort_uniq String.compare

(** Build a set of file paths that belong to executables. *)
let executable_file_set dune_desc =
  Dune.executables dune_desc |> List.concat_map snd
  |> List.map (fun p -> String.lowercase_ascii (Fpath.to_string p))

let check (ctx : Context.project) =
  let files = Context.all_files ctx in
  let lib_modules = Context.lib_modules ctx in
  let test_modules = Context.test_modules ctx in
  let dune_desc = Context.dune_describe ctx in
  let lib_files = library_file_set dune_desc in
  let exec_files = executable_file_set dune_desc in
  let private_modules = private_module_set dune_desc in

  (* E605 checks if library modules have corresponding test files.
     First check dune metadata, then check actual files being analyzed. *)

  (* Debug logging *)
  Logs.debug (fun m ->
      m "E605: Checking %d library modules" (List.length lib_modules));
  Logs.debug (fun m ->
      m "E605: Found %d test modules in dune" (List.length test_modules));
  Logs.debug (fun m ->
      m "E605: Test modules: %a" Fmt.(list ~sep:comma string) test_modules);
  Logs.debug (fun m -> m "E605: Analyzing %d files" (List.length files));

  (* Log test files found in the files list *)
  let test_files_in_list =
    files
    |> List.filter (fun f ->
        String.ends_with ~suffix:".ml" f
        &&
        let basename = Filename.basename f |> Filename.remove_extension in
        String.starts_with ~prefix:"test_" basename || basename = "test")
  in
  Logs.debug (fun m ->
      m "E605: Test .ml files in analyzed files: %d"
        (List.length test_files_in_list));
  List.iter
    (fun f -> Logs.debug (fun m -> m "E605:   - %s" f))
    test_files_in_list;

  if List.length test_files_in_list = 0 && List.length lib_modules > 0 then
    Logs.debug (fun m ->
        m
          "E605: No test files found in analyzed files. Make sure to include \
           test directories in the analysis (e.g., 'merlint lib test' instead \
           of just 'merlint lib')");

  (* Find the source file for a library module, preferring library files over
     executable files. When module names collide (e.g. multiple common.ml in
     different directories), we want the library's source, not the
     executable's. *)
  let find_lib_source lib_mod =
    let matches =
      List.filter
        (fun f ->
          String.ends_with ~suffix:".ml" f
          && Filename.basename (Filename.remove_extension f) = lib_mod)
        files
    in
    (* Prefer files that are known library files *)
    match
      List.find_opt
        (fun f -> List.mem (String.lowercase_ascii f) lib_files)
        matches
    with
    | Some _ as found -> found
    | None ->
        (* Fall back to any match that is NOT an executable file *)
        List.find_opt
          (fun f -> not (List.mem (String.lowercase_ascii f) exec_files))
          matches
  in

  let missing_tests =
    List.filter_map
      (fun lib_mod ->
        (* Skip if this is already a test module *)
        if String.starts_with ~prefix:"test_" lib_mod then None
        else if List.mem (String.lowercase_ascii lib_mod) private_modules then (
          Logs.debug (fun m ->
              m "E605: Skipping module '%s' (listed in private_modules)" lib_mod);
          None)
        else
          (* Find the source file for this module, preferring library files *)
          let module_file = find_lib_source lib_mod in
          match module_file with
          | None ->
              (* No library source file found — the module only exists in
                 executables. Skip it; executable modules don't need E605
                 test files. *)
              Logs.debug (fun m ->
                  m
                    "E605: Skipping module '%s' (no library source file, only \
                     in executables)"
                    lib_mod);
              None
          | Some file_path
            when Astring.String.is_infix ~affix:"/test/" file_path ->
              (* Skip libraries defined in test directories - they are test support libs *)
              Logs.debug (fun m ->
                  m "E605: Skipping module '%s' (defined in test directory)"
                    lib_mod);
              None
          | Some file_path when File.is_in_examples file_path ->
              (* Skip modules in examples directories - they demo usage, not library code *)
              Logs.debug (fun m ->
                  m "E605: Skipping module '%s' (defined in examples directory)"
                    lib_mod);
              None
          | Some file_path when contains_only_types_and_modules file_path ->
              Logs.debug (fun m ->
                  m "E605: Skipping module '%s' (contains only types/modules)"
                    lib_mod);
              None
          | Some file_path ->
              (* Use lowercase for comparison: OS.ml -> test_os (not test_OS) *)
              let expected_test_name =
                "test_" ^ String.lowercase_ascii lib_mod
              in

              (* Debug what we're checking *)
              let in_dune =
                List.mem expected_test_name
                  (List.map String.lowercase_ascii test_modules)
              in
              let in_files =
                List.exists
                  (fun f ->
                    String.ends_with ~suffix:".ml" f
                    && String.lowercase_ascii
                         (Filename.basename (Filename.remove_extension f))
                       = expected_test_name)
                  files
              in

              Logs.debug (fun m ->
                  m "E605: Checking %s -> %s (in_dune=%b, in_files=%b)" lib_mod
                    expected_test_name in_dune in_files);

              (* Check both:
                 1. If test module exists in dune metadata (test_modules)
                 2. If test file exists in the files being analyzed *)
              if (not in_dune) && not in_files then Some (lib_mod, file_path)
              else None)
      lib_modules
  in
  List.map
    (fun (m, source_file) -> create_missing_test_issue m source_file)
    missing_tests

let pp ppf { module_name; expected_test_file } =
  Fmt.pf ppf "Library module '%s' is missing test file (expected: %s)"
    module_name expected_test_file

let rule =
  Rule.v ~code:"E605" ~title:"Missing Test File" ~category:Testing
    ~hint:
      "Each library module should have a corresponding test file to ensure \
       proper testing coverage. Create test files following the naming \
       convention test_<module>.ml"
    ~examples:[] ~pp (Project check)
