(** E600: Test Module Convention *)

module Parsetree = Ocaml_parsing.Parsetree
module Ast_iterator = Ocaml_parsing.Ast_iterator
module Longident = Ocaml_parsing.Longident

type reason =
  | Runner_defines_inline_tests
  | Runner_in_module
  | Missing_interface
  | Bad_interface

type payload = { filename : string; module_name : string; reason : reason }

let log_src = Logs.Src.create "merlint.rules.e600" ~doc:"E600 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

let is_test_file filename =
  (* Only test executables named test.ml should follow this convention *)
  Filename.basename filename = "test.ml"

let lident_path lid = Longident.flatten lid

let has_ident view pred =
  match File_view.parsetree view with
  | None -> false
  | Some structure ->
      let found = ref false in
      let iterator =
        {
          Ast_iterator.default_iterator with
          expr =
            (fun self expr ->
              (match expr.Parsetree.pexp_desc with
              | Pexp_ident { txt; _ } when pred (lident_path txt) ->
                  found := true
              | _ -> ());
              if not !found then Ast_iterator.default_iterator.expr self expr);
        }
      in
      iterator.structure iterator structure;
      !found

let has_test_runner view =
  has_ident view (function [ "Alcotest"; "run" ] -> true | _ -> false)

let uses_test_module_suites view =
  has_ident view (function
    | [ module_name; "suite" ] -> String.starts_with ~prefix:"Test_" module_name
    | _ -> false)

let pat_name (pat : Parsetree.pattern) =
  match pat.ppat_desc with Ppat_var { txt; _ } -> Some txt | _ -> None

let rec is_list_expr (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> true
  | Pexp_construct ({ txt = Lident "::"; _ }, Some _) -> true
  | Pexp_constraint (expr, _) | Pexp_coerce (expr, _, _) -> is_list_expr expr
  | _ -> false

let defines_own_tests view =
  match File_view.parsetree view with
  | None -> false
  | Some structure ->
      List.exists
        (fun (item : Parsetree.structure_item) ->
          match item.pstr_desc with
          | Pstr_value (_, bindings) ->
              List.exists
                (fun (vb : Parsetree.value_binding) ->
                  match pat_name vb.pvb_pat with
                  | Some ("tests" | "suite") -> is_list_expr vb.pvb_expr
                  | _ -> false)
                bindings
          | _ -> false)
        structure

let test_mli_needs_issue view =
  not
    (Suite_mli.is_compliant_view
       ~expected:"string * unit Alcotest.test_case list" view)

let test_mli_target dune_describe filename =
  let basename = Filename.basename filename in
  File_kind.is_mli basename
  && String.starts_with ~prefix:"test_" basename
  && basename <> "test.mli"
  && (not (File.is_in_private_library dune_describe filename))
  && not (File.is_in_examples filename)

(** Check if a test.ml file properly uses test module suites instead of defining
    its own tests. *)
let check_test_file_uses_modules filename view =
  Log.debug (fun m -> m "E600: Checking file %s" filename);
  if not (is_test_file filename) then (
    Log.debug (fun m -> m "E600:   Not a test.ml file");
    [])
  else if not (has_test_runner view) then (
    Log.debug (fun m -> m "E600:   No test runner found");
    [])
  else
    let defines_own = defines_own_tests view in
    let uses_modules = uses_test_module_suites view in
    Log.debug (fun m ->
        m "E600:   defines_own_tests=%b, uses_test_module_suites=%b" defines_own
          uses_modules);
    if defines_own && not uses_modules then (
      (* Issue if test.ml defines its own tests instead of using test modules *)
      Log.debug (fun m ->
          m "E600:   Found issue - defines own tests without using modules");
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          {
            filename;
            module_name = "test";
            reason = Runner_defines_inline_tests;
          };
      ])
    else (
      Log.debug (fun m -> m "E600:   No issue found");
      [])

(** Check if test_*.ml file incorrectly contains Alcotest.run. The test runner
    should only be in test.ml, not in individual test modules. *)
let check_runner_in_wrong_file filename view =
  let basename = Filename.basename filename in
  if
    File_kind.is_ml basename
    && String.starts_with ~prefix:"test_" basename
    && basename <> "test.ml"
    && (not (File.is_in_examples filename))
    && has_test_runner view
  then
    [
      Issue.v
        ~loc:
          (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
             ~end_col:0)
        {
          filename;
          module_name = basename |> Filename.chop_extension;
          reason = Runner_in_module;
        };
    ]
  else []

(** Check if a test_*.mli file exports only suite with correct type. Skips files
    that belong to private libraries. *)
let check_test_mli_file dune_describe filename view =
  let basename = Filename.basename filename in
  if test_mli_target dune_describe filename then
    if test_mli_needs_issue view then
      [
        Issue.v
          ~loc:
            (Location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
               ~end_col:0)
          {
            filename;
            module_name = basename |> Filename.chop_extension;
            reason = Bad_interface;
          };
      ]
    else []
  else []

let test_ml_target dune_describe ml_file =
  let basename = Filename.basename ml_file in
  File_kind.is_ml ml_file
  && String.starts_with ~prefix:"test_" basename
  && basename <> "test.ml"
  && (not (File.is_in_private_library dune_describe ml_file))
  && not (File.is_in_examples ml_file)

let file_has_runner ctx ml_file =
  try has_test_runner (Context.file_view ctx ml_file)
  with File_view.Analysis_error _ -> false

let missing_test_mli_issue files ml_file =
  let mli_path = Filename.remove_extension ml_file ^ ".mli" in
  if List.mem mli_path files then None
  else
    let basename = Filename.basename ml_file in
    let loc =
      Location.v ~file:ml_file ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
    in
    Some
      (Issue.v ~loc
         {
           filename = ml_file;
           module_name = Filename.chop_extension basename;
           reason = Missing_interface;
         })

(** Check if test_*.ml files have corresponding .mli files. Skip files that
    contain Alcotest.run since they shouldn't be test modules, and files that
    belong to private libraries. *)
let check_missing_test_mli ctx dune_describe files =
  List.filter_map
    (fun ml_file ->
      if
        test_ml_target dune_describe ml_file
        && not (file_has_runner ctx ml_file)
      then missing_test_mli_issue files ml_file
      else None)
    files

(** Check all files for test convention issues *)
let check ctx =
  let files = Context.all_files ctx in
  let dune_describe = Context.dune_describe ctx in
  (* Debug log to see what files we're analyzing *)
  Log.debug (fun m -> m "E600: Analyzing %d files:" (List.length files));
  List.iter (fun f -> Log.debug (fun m -> m "E600:   - %s" f)) files;

  (* Check for missing .mli files for test modules *)
  let missing_mli_issues = check_missing_test_mli ctx dune_describe files in

  let content_issues =
    List.concat_map
      (fun filename ->
        if File_kind.is_ml_or_mli filename then
          try
            let view = Context.file_view ctx filename in
            check_test_file_uses_modules filename view
            @ check_runner_in_wrong_file filename view
            @ check_test_mli_file dune_describe filename view
          with File_view.Analysis_error _ -> []
        else [])
      files
  in

  missing_mli_issues @ content_issues

let pp ppf { filename; module_name = _; reason } =
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
    ~examples:[] ~pp (Project check)
