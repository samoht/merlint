(** E610: Test Without Library *)

module Issue_location = Location

type payload = {
  expected_module : string;
  unscanned : string list;
      (** Library sources whose [.cmt]/[.cmti] no longer describes them, sorted.
          Empty when the reference scan read every library source, which is what
          makes an absence a fact rather than a guess. *)
}

let log_src = Logs.Src.create "merlint.rules.e610" ~doc:"E610 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)
module String_set = Set.Make (String)

(** Find "test/" in path, handling both absolute (/test/) and relative (test/)
    paths. Returns the index after "test/" if found. *)
let test_prefix path =
  match Re.exec_opt Re.(compile (str "/test/")) path with
  | Some g -> Some (Re.Group.start g 0 + 6)
  | None -> if String.starts_with ~prefix:"test/" path then Some 5 else None

(** Find "lib/" in path, handling both absolute (/lib/) and relative (lib/)
    paths. Returns the index after "lib/" if found. *)
let lib_prefix path =
  match Re.exec_opt Re.(compile (str "/lib/")) path with
  | Some g -> Some (Re.Group.start g 0 + 5)
  | None -> if String.starts_with ~prefix:"lib/" path then Some 4 else None

(** Extract the relative path from test/ directory. e.g., "test/foo/test_x.ml"
    -> "foo/x.ml" "test/test_x.ml" -> "x.ml" *)
let expected_lib_path test_file =
  let path = Fpath.to_string test_file in
  (* Find "test/" in the path and extract what comes after *)
  match test_prefix path with
  | Some idx ->
      let after_test = String.sub path idx (String.length path - idx) in
      (* Replace test_x.ml with x.ml *)
      let basename = Filename.basename after_test in
      let dirname = Filename.dirname after_test in
      if String.starts_with ~prefix:"test_" basename then
        let lib_basename = String.sub basename 5 (String.length basename - 5) in
        Some
          (if dirname = "." then lib_basename
           else Filename.concat dirname lib_basename)
      else None
  | None ->
      (* Fallback: just use basename *)
      let basename = Fpath.(test_file |> rem_ext |> basename) in
      if String.starts_with ~prefix:"test_" basename then
        Some (String.sub basename 5 (String.length basename - 5) ^ ".ml")
      else None

let library_module_path ctx file =
  let file = Context.resolve ctx file in
  let rel_file = Fpath.v (Context.project_relative_path ctx file) in
  (* [.mll] (ocamllex) and [.mly] (ocamlyacc/menhir) generate a [.ml] module of
     the same name at build time, so they provide the library module a test
     exercises just as a [.ml] source does. Normalise them to [.ml] so the
     test<->module pairing matches. *)
  let provides_module =
    Fpath.has_ext ".ml" rel_file
    || Fpath.has_ext ".mll" rel_file
    || Fpath.has_ext ".mly" rel_file
  in
  if not provides_module then None
  else
    let rel_file = Fpath.set_ext ".ml" rel_file in
    let path = Fpath.to_string rel_file in
    match lib_prefix path with
    | Some idx ->
        let result = String.sub path idx (String.length path - idx) in
        Log.debug (fun m -> m "E610: lib path %s -> %s" path result);
        Some result
    | None ->
        Log.debug (fun m -> m "E610: lib path %s (no lib/ prefix)" path);
        Some path

let library_module_paths ctx libraries =
  List.concat_map
    (fun lib ->
      List.filter_map (library_module_path ctx)
        (Project_index.Library.files lib))
    libraries

let library_source_files ctx libraries =
  List.concat_map
    (fun lib ->
      List.filter_map
        (fun file ->
          if Fpath.has_ext ".ml" file || Fpath.has_ext ".mli" file then
            Some (Context.resolve ctx file)
          else None)
        (Project_index.Library.files lib))
    libraries

type env = {
  library_module_paths : string list;
  referenced_modules : String_set.t;
  unscanned : string list;
      (** The library sources the reference scan could not read. *)
  provided_basenames : String_set.t;
      (** Lower-cased [<module>.ml] basenames of the modules the test's own
          declared libraries provide. A test in a non-mirroring directory (an
          imported [legacy/] suite) or one for a library's namesake wrapper
          module -- which nothing references by name -- still has a real library
          module behind it; "Test Without Library" must not fire then. *)
}

type work = { env : env; file : Context.path; rel_file : Fpath.t }

let module_path_matches ~expected_path lib_path =
  let expected_lc = String.lowercase_ascii expected_path in
  let expected_dir = String.lowercase_ascii (Filename.dirname expected_path) in
  let expected_base =
    String.lowercase_ascii (Filename.basename expected_path)
  in
  let lib_lc = String.lowercase_ascii lib_path in
  let lib_base = String.lowercase_ascii (Filename.basename lib_path) in
  lib_lc = expected_lc
  || lib_base = expected_base
     && (expected_dir = "."
        || String.starts_with ~prefix:(expected_dir ^ "/") lib_lc
        || (expected_dir = "" && lib_lc = lib_base)
        || Astring.String.is_infix
             ~affix:("/" ^ expected_dir ^ "/" ^ expected_base)
             lib_lc
        (* A flat library module (no subdirectory) matches a same-named test
           however deep its directory: a sub-library whose test executable
           needs extra deps lives in test/<x>/ while the module stays at lib
           root. *)
        || lib_lc = lib_base)

let missing_library_issue ~unscanned file expected_path =
  let loc =
    Issue_location.v
      ~file:(Context.string_of_path file)
      ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
  in
  Issue.v ~loc { expected_module = expected_path; unscanned }

type scan = { names : String_set.t; unread : string list }

(* A platform- or config-gated stanza is one the host does not build, so its
   artefact is legitimately absent and names no defect the user can act on. *)
let gated_source ctx =
  let norm path = Fpath.(v path |> normalize |> to_string) in
  let gated =
    Project_index.gated_source_files (Context.index ctx)
    |> List.map (fun p -> norm (Fpath.to_string p))
    |> String_set.of_list
  in
  fun path -> String_set.mem (norm (Context.string_of_path path)) gated

(* The reference scan is the only artefact-backed evidence this rule holds: a
   module defined inside another compilation unit is named nowhere but that
   unit's typedtree. A library source whose [.cmt] no longer describes it
   withholds the references it carries, so an absence read off the remainder is
   a guess. Record those sources and let the finding say which reading it is. *)
let scan_library_file ctx ~gated acc path =
  if not (Path.has_ext ".ml" path || Path.has_ext ".mli" path) then acc
  else
    let unread () =
      if gated path then acc
      else
        {
          acc with
          unread = Context.project_relative_path ctx path :: acc.unread;
        }
    in
    match
      let view = Context.file_view ctx path in
      if File_view.is_resolved view then
        Some (File_view.referenced_module_names view)
      else None
    with
    | exception Context.Analysis_error _ -> unread ()
    | None -> unread ()
    | Some names ->
        {
          acc with
          names =
            List.fold_left
              (fun acc name -> String_set.add name acc)
              acc.names names;
        }

let scan_libraries ctx library_source_files =
  let gated = gated_source ctx in
  let scan =
    List.fold_left
      (scan_library_file ctx ~gated)
      { names = String_set.empty; unread = [] }
      library_source_files
  in
  { scan with unread = List.sort_uniq String.compare scan.unread }

let check_test_file ~library_module_paths ~referenced_modules ~unscanned
    ~provided_basenames ~file ~rel_file =
  let test_module = Fpath.(rel_file |> rem_ext |> basename) in
  if
    (not (Fpath.has_ext ".ml" rel_file))
    || (not (String.starts_with ~prefix:"test_" test_module))
    || File.is_in_examples (Fpath.to_string rel_file)
  then None
  else
    match expected_lib_path rel_file with
    | None -> None
    | Some expected_path ->
        Log.debug (fun m ->
            m "E610: test %a expects lib %s" Path.pp file expected_path);
        let found =
          List.exists (module_path_matches ~expected_path) library_module_paths
        in
        let module_name =
          Filename.remove_extension (Filename.basename expected_path)
        in
        let cap_name = String.capitalize_ascii module_name in
        let referenced =
          (not found) && String_set.mem cap_name referenced_modules
        in
        let provided =
          (not found) && (not referenced)
          && String_set.mem
               (String.lowercase_ascii (Filename.basename expected_path))
               provided_basenames
        in
        Log.debug (fun m ->
            m "E610: found=%b referenced=%b provided=%b" found referenced
              provided);
        if found || referenced || provided then None
        else Some (missing_library_issue ~unscanned file expected_path)

(* Lower-cased [<module>.ml] basenames provided by [stanza]'s own declared
   libraries -- the modules a test in this stanza is entitled to exercise even
   when the source directory does not mirror the test directory. *)
let stanza_provided_basenames ctx (stanza : Project_index.source_stanza) =
  let index = Context.index ctx in
  stanza.libraries
  |> List.concat_map (Project_index.libraries_of_name index)
  |> List.concat_map Project_index.Library.files
  |> List.filter_map (fun f ->
      let s = Fpath.to_string f in
      if
        Filename.check_suffix s ".ml"
        || Filename.check_suffix s ".mli"
        || Filename.check_suffix s ".mll"
        || Filename.check_suffix s ".mly"
      then
        Some
          (String.lowercase_ascii
             (Filename.remove_extension (Filename.basename s))
          ^ ".ml")
      else None)
  |> String_set.of_list

let enumerate ctx =
  let libraries = Project.Query.source_libraries (Context.index ctx) in
  let library_module_paths = library_module_paths ctx libraries in
  let library_source_files = library_source_files ctx libraries in
  let scan = scan_libraries ctx library_source_files in
  Log.debug (fun m ->
      m "E610: library_module_paths = %a"
        Fmt.(list ~sep:comma string)
        library_module_paths);
  Log.debug (fun m ->
      m "E610: unscanned = %a" Fmt.(list ~sep:comma string) scan.unread);
  Context.test_stanzas ctx
  |> List.concat_map (fun (stanza : Project_index.source_stanza) ->
      let provided_basenames = stanza_provided_basenames ctx stanza in
      let env =
        {
          library_module_paths;
          referenced_modules = scan.names;
          unscanned = scan.unread;
          provided_basenames;
        }
      in
      stanza.files
      |> List.filter_map (fun file ->
          let file = Context.resolve ctx file in
          let rel_file = Fpath.v (Context.project_relative_path ctx file) in
          let path = Fpath.to_string rel_file in
          if
            ctx.Context.in_analyze_set file
            && File_kind.is_ml path
            && String.starts_with ~prefix:"test_"
                 Fpath.(rel_file |> rem_ext |> basename)
            && not (File.is_in_examples path)
          then Some { env; file; rel_file }
          else None))

let check_unit { env; file; rel_file } =
  match
    check_test_file ~library_module_paths:env.library_module_paths
      ~referenced_modules:env.referenced_modules ~unscanned:env.unscanned
      ~provided_basenames:env.provided_basenames ~file ~rel_file
  with
  | None -> []
  | Some issue -> [ issue ]

let pp_unscanned ppf = function
  | [] -> ()
  | [ file ] -> Fmt.string ppf file
  | file :: rest ->
      Fmt.pf ppf "%s and %d more library source%s" file (List.length rest)
        (if List.compare_length_with rest 1 = 0 then "" else "s")

let pp ppf { expected_module; unscanned } =
  match unscanned with
  | [] ->
      Fmt.pf ppf
        "Test file exists but corresponding library module '%s' not found"
        expected_module
  | _ :: _ ->
      Fmt.pf ppf
        "Missing or stale .cmt/.cmti for %a, so library module '%s' is either \
         present and unread or genuinely absent. Run [dune build @check] \
         before merlint so the build artefacts are present and up to date."
        pp_unscanned unscanned expected_module

let rule =
  Rule.v ~code:"E610" ~title:"Test Without Library" ~category:Testing
    ~hint:
      "Every test module should have a corresponding library module. This \
       ensures that tests are testing actual library functionality rather than \
       testing code that doesn't exist in the library."
    ~examples:[] ~pp
    (Project_units { enumerate; check = Fun.const check_unit })
