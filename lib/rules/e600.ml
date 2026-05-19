(** E600: Test Module Convention *)

module T = Ocaml_typing.Typedtree

type reason =
  | Runner_defines_inline_tests
  | Runner_in_module
  | Missing_interface
  | Bad_interface

type payload = { filename : string; reason : reason }

let log_src = Logs.Src.create "merlint.rules.e600" ~doc:"E600 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

let is_test_file filename =
  (* Only test executables named test.ml should follow this convention *)
  Filename.basename filename = "test.ml"

let is_test_module_basename basename =
  String.starts_with ~prefix:"test_" basename
  && not (File.is_unit_companion_module basename)

let is_library_file index filename =
  let file = Fpath.v filename in
  Project_index.libraries_of_file index file <> []
  || Project_index.has_library_stanza_in_dir index (Fpath.parent file)

let rec is_list_expr (expr : T.expression) =
  match expr.exp_desc with
  | Texp_construct (lid, _, _) ->
      List.mem (Ocaml_parsing.Longident.flatten lid.txt) [ [ "[]" ]; [ "::" ] ]
  | Texp_open (_, expr) -> is_list_expr expr
  | _ -> false

let binding_defines_tests (vb : T.value_binding) =
  match vb.vb_pat.pat_desc with
  | Tpat_var (_, name, _) when List.mem name.txt [ "tests"; "suite" ] ->
      is_list_expr vb.vb_expr
  | _ -> false

let item_defines_tests (item : T.structure_item) =
  match item.str_desc with
  | Tstr_value (_, bindings) -> List.exists binding_defines_tests bindings
  | _ -> false

let test_mli_needs_issue view =
  match File_view.typedtree view with
  | None -> false
  | Some _ ->
      not
        (Suite.is_compliant_view
           ~expected:"string * unit Alcotest.test_case list" view)

let test_mli_target index filename =
  let basename = Filename.basename filename in
  File_kind.is_mli basename
  && is_test_module_basename (Filename.remove_extension basename)
  && basename <> "test.mli"
  && (not (is_library_file index filename))
  && (not (File.is_in_private_library index filename))
  && not (File.is_in_examples filename)

let runner_in_wrong_file_target index filename =
  let basename = Filename.basename filename in
  File_kind.is_ml basename
  && is_test_module_basename (Filename.remove_extension basename)
  && basename <> "test.ml"
  && (not (is_library_file index filename))
  && not (File.is_in_examples filename)

(** Check if a test_*.mli file exports only suite with correct type. Skips files
    that belong to private libraries. *)
let check_test_mli_file index filename view =
  if test_mli_target index filename then
    if test_mli_needs_issue view then
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; reason = Bad_interface };
      ]
    else []
  else []

let content_target index filename =
  is_test_file filename
  || runner_in_wrong_file_target index filename
  || test_mli_target index filename

let test_ml_target index ml_file =
  let basename = Filename.basename ml_file in
  File_kind.is_ml ml_file
  && is_test_module_basename (Filename.remove_extension basename)
  && basename <> "test.ml"
  && (not (is_library_file index ml_file))
  && (not (File.is_in_private_library index ml_file))
  && not (File.is_in_examples ml_file)

let missing_test_mli_issue files ml_file =
  let mli_path = Filename.remove_extension ml_file ^ ".mli" in
  if files mli_path then None
  else
    let loc =
      Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    in
    Some (Issue.v ~loc { filename = ml_file; reason = Missing_interface })

(** Check if test_*.ml files have corresponding .mli files. Skip files that
    contain Alcotest.run since they shouldn't be test modules, and files that
    belong to private libraries. *)
let check_missing_test_mli ctx index ml_file ~has_runner =
  if test_ml_target index ml_file && not has_runner then
    missing_test_mli_issue ctx.Context.selected_file ml_file
  else None

let path_ends_with path suffix =
  let rec drop n xs =
    if n <= 0 then xs else match xs with [] -> [] | _ :: xs -> drop (n - 1) xs
  in
  let len = List.length path in
  let suffix_len = List.length suffix in
  len >= suffix_len && drop (len - suffix_len) path = suffix

let expr_calls expr suffix =
  match Query.Expr.callee_parts expr with
  | Some path -> path_ends_with path suffix
  | None -> false

let expr_references_test_suite expr =
  match expr.T.exp_desc with
  | Texp_ident (path, _, _) -> (
      match List.rev (Query.Path.parts path) with
      | "suite" :: module_name :: _ ->
          String.starts_with ~prefix:"Test_" module_name
      | _ -> false)
  | _ -> false

type state = {
  filename : string;
  index : Project_index.t option;
  mutable has_runner : bool;
  mutable defines_own : bool;
  mutable uses_test_suite : bool;
}

let visit_expr state (expr : T.expression) =
  if not state.has_runner then
    state.has_runner <- expr_calls expr [ "Alcotest"; "run" ];
  if not state.uses_test_suite then
    state.uses_test_suite <- expr_references_test_suite expr

let visit_structure_item state item =
  if is_test_file state.filename && not state.defines_own then
    state.defines_own <- item_defines_tests item

let content_issues ctx index state =
  let filename = state.filename in
  let runner_issue =
    if
      is_test_file filename && state.has_runner && state.defines_own
      && not state.uses_test_suite
    then
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; reason = Runner_defines_inline_tests };
      ]
    else []
  in
  let wrong_file_issue =
    if runner_in_wrong_file_target index filename && state.has_runner then
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          { filename; reason = Runner_in_module };
      ]
    else []
  in
  let bad_mli_issue =
    if test_mli_target index filename then
      check_test_mli_file index filename (Context.view ctx)
    else []
  in
  runner_issue @ wrong_file_issue @ bad_mli_issue

let init ctx =
  {
    filename = ctx.Context.filename;
    index = ctx.Context.project_index;
    has_runner = false;
    defines_own = false;
    uses_test_suite = false;
  }

let select ctx =
  match ctx.Context.project_index with
  | None -> false
  | Some index ->
      let filename = ctx.filename in
      test_ml_target index filename || content_target index filename

let finish ctx state =
  match state.index with
  | None -> []
  | Some index ->
      let filename = state.filename in
      if test_ml_target index filename || content_target index filename then
        Option.to_list
          (check_missing_test_mli ctx index filename
             ~has_runner:state.has_runner)
        @ content_issues ctx index state
      else []

let pp ppf { filename; reason } =
  match reason with
  | Bad_interface ->
      Fmt.pf ppf
        "Test module interface should only export 'suite' with type string * \
         unit Alcotest.test_case list"
  | Runner_in_module ->
      let basename = Filename.basename filename in
      Fmt.pf ppf
        "Alcotest.run should be in test.ml, not in %s - test modules should \
         only export a suite value"
        basename
  | Missing_interface ->
      Fmt.pf ppf "Test module %s is missing interface file %s" filename
        (Filename.remove_extension filename ^ ".mli")
  | Runner_defines_inline_tests ->
      Fmt.pf ppf
        "Test file should use test module suites (e.g., Test_user.suite) \
         instead of defining its own test list"

let rule =
  Rule.v ~code:"E600" ~title:"Test Module Convention" ~category:Testing
    ~hint:
      "Enforces proper test organization: (1) Test executables (test.ml) \
       should use test suites from test modules (e.g., Test_user.suite) rather \
       than defining their own test lists directly. (2) Test module interfaces \
       (test_*.mli) should only export a 'suite' value with type 'string * \
       unit Alcotest.test_case list' and no other values. (3) Alcotest.run \
       should only appear in test.ml, not in individual test_*.ml modules."
    ~examples:[] ~pp
    (Rule.pass ~select ~init ~expr:visit_expr
       ~structure_item:visit_structure_item ~finish ())
