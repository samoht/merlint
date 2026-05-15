(** E610: Test Without Library *)

type payload = { test_file : string; expected_module : string }

let log_src = Logs.Src.create "merlint.rules.e610" ~doc:"E610 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

(** Find "test/" in path, handling both absolute (/test/) and relative (test/)
    paths. Returns the index after "test/" if found. *)
let find_test_prefix path =
  match Astring.String.find_sub ~sub:"/test/" path with
  | Some idx -> Some (idx + 6)
  | None -> if String.starts_with ~prefix:"test/" path then Some 5 else None

(** Find "lib/" in path, handling both absolute (/lib/) and relative (lib/)
    paths. Returns the index after "lib/" if found. *)
let find_lib_prefix path =
  match Astring.String.find_sub ~sub:"/lib/" path with
  | Some idx -> Some (idx + 5)
  | None -> if String.starts_with ~prefix:"lib/" path then Some 4 else None

(** Extract the relative path from test/ directory. e.g., "test/foo/test_x.ml"
    -> "foo/x.ml" "test/test_x.ml" -> "x.ml" *)
let expected_lib_path test_file =
  let path = Fpath.to_string test_file in
  (* Find "test/" in the path and extract what comes after *)
  match find_test_prefix path with
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

let library_module_path file =
  if not (Fpath.has_ext ".ml" file) then None
  else
    let path = Fpath.to_string file in
    match find_lib_prefix path with
    | Some idx ->
        let result = String.sub path idx (String.length path - idx) in
        Log.debug (fun m -> m "E610: lib path %s -> %s" path result);
        Some result
    | None ->
        Log.debug (fun m -> m "E610: lib path %s (no lib/ prefix)" path);
        Some path

let library_module_paths libraries =
  List.concat_map
    (fun (lib_info : Dune_describe.library_info) ->
      List.filter_map library_module_path lib_info.files)
    libraries

let library_source_files libraries =
  List.concat_map
    (fun (lib_info : Dune_describe.library_info) ->
      List.filter_map
        (fun file ->
          if Fpath.has_ext ".ml" file || Fpath.has_ext ".mli" file then
            Some (Fpath.to_string file)
          else None)
        lib_info.files)
    libraries

module String_set = Set.Make (String)

(** AST iterator that records the leading segment of every module path in the
    tree (the [Foo] of [Foo.x], [Foo.Bar.t], [open Foo], [include Foo],
    [module M = Foo], [type t = Foo.t], constructor patterns, etc.). The leading
    segment alone is enough for E610: it just needs to know whether a given
    module name is referenced anywhere. *)
let rec head_of_lid : Longident.t -> string option = function
  | Lident s -> Some s
  | Ldot (l, _) -> head_of_lid l.txt
  | Lapply (l, _) -> head_of_lid l.txt

let module_ref_iterator acc =
  let add_lid lid =
    match head_of_lid lid with
    | Some head
      when String.length head > 0 && head.[0] >= 'A' && head.[0] <= 'Z' ->
        acc := String_set.add head !acc
    | _ -> ()
  in
  let add_name name = acc := String_set.add name !acc in
  {
    Ast_iterator.default_iterator with
    module_binding =
      (fun self mb ->
        (match mb.pmb_name.txt with Some n -> add_name n | None -> ());
        Ast_iterator.default_iterator.module_binding self mb);
    module_declaration =
      (fun self md ->
        (match md.pmd_name.txt with Some n -> add_name n | None -> ());
        Ast_iterator.default_iterator.module_declaration self md);
    expr =
      (fun self e ->
        (match e.pexp_desc with
        | Pexp_ident { txt; _ } | Pexp_construct ({ txt; _ }, _) -> add_lid txt
        | _ -> ());
        Ast_iterator.default_iterator.expr self e);
    typ =
      (fun self c ->
        (match c.ptyp_desc with
        | Ptyp_constr ({ txt; _ }, _) | Ptyp_class ({ txt; _ }, _) ->
            add_lid txt
        | _ -> ());
        Ast_iterator.default_iterator.typ self c);
    pat =
      (fun self p ->
        (match p.ppat_desc with
        | Ppat_construct ({ txt; _ }, _) -> add_lid txt
        | _ -> ());
        Ast_iterator.default_iterator.pat self p);
    module_expr =
      (fun self me ->
        (match me.pmod_desc with
        | Pmod_ident { txt; _ } -> add_lid txt
        | _ -> ());
        Ast_iterator.default_iterator.module_expr self me);
    module_type =
      (fun self mty ->
        (match mty.pmty_desc with
        | Pmty_ident { txt; _ } | Pmty_alias { txt; _ } -> add_lid txt
        | _ -> ());
        Ast_iterator.default_iterator.module_type self mty);
    open_declaration =
      (fun self od ->
        (match od.popen_expr.pmod_desc with
        | Pmod_ident { txt; _ } -> add_lid txt
        | _ -> ());
        Ast_iterator.default_iterator.open_declaration self od);
  }

let collect_refs_in_structure structure acc =
  let acc = ref acc in
  let iter = module_ref_iterator acc in
  iter.structure iter structure;
  !acc

let collect_refs_in_signature signature acc =
  let acc = ref acc in
  let iter = module_ref_iterator acc in
  iter.signature iter signature;
  !acc

let with_lexbuf path f =
  try
    let ic = open_in path in
    Fun.protect
      ~finally:(fun () -> close_in ic)
      (fun () ->
        let lexbuf = Lexing.from_channel ic in
        lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = path };
        Some (f lexbuf))
  with Sys_error _ | Syntaxerr.Error _ | Lexer.Error _ -> None

(** Project-wide set of module names referenced anywhere in [files]. Parse each
    [.ml] / [.mli] once via compiler-libs and walk the AST. The resulting set is
    consulted by per-test lookups to decide whether a test's expected library
    module is referenced (and therefore counts as "exists in some library
    form"). *)
let collect_referenced_modules files =
  List.fold_left
    (fun acc path ->
      if Filename.check_suffix path ".ml" then
        match with_lexbuf path Parse.implementation with
        | None -> acc
        | Some structure -> collect_refs_in_structure structure acc
      else if Filename.check_suffix path ".mli" then
        match with_lexbuf path Parse.interface with
        | None -> acc
        | Some signature -> collect_refs_in_signature signature acc
      else acc)
    String_set.empty files

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
             lib_lc)

let missing_library_issue file expected_path =
  let loc =
    Location.v ~file:(Fpath.to_string file) ~start_line:1 ~start_col:0
      ~end_line:1 ~end_col:0
  in
  Issue.v ~loc
    { test_file = Fpath.to_string file; expected_module = expected_path }

let check_test_file ~library_module_paths ~referenced_modules file =
  let test_module = Fpath.(file |> rem_ext |> basename) in
  if
    (not (Fpath.has_ext ".ml" file))
    || (not (String.starts_with ~prefix:"test_" test_module))
    || File.is_in_examples (Fpath.to_string file)
  then None
  else
    match expected_lib_path file with
    | None -> None
    | Some expected_path ->
        Log.debug (fun m ->
            m "E610: test %s expects lib %s" (Fpath.to_string file)
              expected_path);
        let found =
          List.exists (module_path_matches ~expected_path) library_module_paths
        in
        let module_name =
          Filename.remove_extension (Filename.basename expected_path)
        in
        let cap_name = String.capitalize_ascii module_name in
        let referenced = String_set.mem cap_name referenced_modules in
        Log.debug (fun m -> m "E610: found=%b referenced=%b" found referenced);
        if found || referenced then None
        else Some (missing_library_issue file expected_path)

let check ctx =
  let dune_describe = Context.dune_describe ctx in
  let libraries = Dune_describe.libraries dune_describe in
  let library_module_paths = library_module_paths libraries in
  let referenced_modules =
    collect_referenced_modules (library_source_files libraries)
  in
  Log.debug (fun m ->
      m "E610: library_module_paths = %a"
        Fmt.(list ~sep:comma string)
        library_module_paths);
  Dune_describe.tests dune_describe
  |> List.concat_map (fun (test_info : Dune_describe.test_info) ->
      test_info.files)
  |> List.filter_map (check_test_file ~library_module_paths ~referenced_modules)

let pp ppf { test_file = _; expected_module } =
  Fmt.pf ppf "Test file exists but corresponding library module '%s' not found"
    expected_module

let rule =
  Rule.v ~code:"E610" ~title:"Test Without Library" ~category:Testing
    ~hint:
      "Every test module should have a corresponding library module. This \
       ensures that tests are testing actual library functionality rather than \
       testing code that doesn't exist in the library."
    ~examples:[] ~pp (Project check)
