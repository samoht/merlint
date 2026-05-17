(** E617: Test Suite Naming Convention *)

module Issue_location = Location
module T = Ocaml_typing.Typedtree

type issue_type =
  | Not_lowercase of string
  | Not_snake_case of string
  | Wrong_name of { actual : string; expected : string }

type payload = { suite_name : string; issue_type : issue_type }

let is_snake_case s =
  let rec check i =
    if i >= String.length s then true
    else
      match s.[i] with
      | 'a' .. 'z' | '0' .. '9' | '_' -> check (i + 1)
      | _ -> false
  in
  check 0

let extract_expected_name filename =
  let basename = Filename.basename filename in
  if String.starts_with ~prefix:"test_" basename then
    let name = Filename.chop_extension basename in
    String.sub name 5 (String.length name - 5)
  else if basename = "test.ml" then "test"
  else Filename.chop_extension basename

(** Extract suite name from a [let suite = ...] binding using the typedtree.
    Handles both [let suite = ("name", ...)] and
    [let suite = \n  ("name", ...)]. *)
let extract_suite_name_of_expr (expr : T.expression) =
  match expr.exp_desc with
  | Texp_tuple ((None, name_expr) :: _) ->
      Option.map
        (fun name -> (name, expr.exp_loc))
        (Query.Expr.string name_expr)
  | _ -> None

(** Locate the suite name from a typed structure by looking for
    [let suite = ("name", ...)] bindings. *)
let suite_name view =
  let found = ref None in
  Query.iter_structure_items view (fun (item : T.structure_item) ->
      match (item.str_desc, !found) with
      | Tstr_value (_, bindings), None ->
          found :=
            List.find_map
              (fun (vb : T.value_binding) ->
                match Query.Pattern.var_name vb.vb_pat with
                | Some "suite" -> extract_suite_name_of_expr vb.vb_expr
                | _ -> None)
              bindings
      | _ -> ());
  !found

let suite_issue ~filename ~expected_name
    ((suite_name, name_loc) : string * Ocaml_parsing.Location.t) =
  let loc =
    Issue_location.v ~file:filename
      ~start_line:name_loc.Ocaml_parsing.Location.loc_start.pos_lnum
      ~start_col:0 ~end_line:name_loc.Ocaml_parsing.Location.loc_start.pos_lnum
      ~end_col:80
  in
  if suite_name <> String.lowercase_ascii suite_name then
    Some
      (Issue.v ~loc
         {
           suite_name;
           issue_type = Not_lowercase (String.lowercase_ascii suite_name);
         })
  else if not (is_snake_case suite_name) then
    Some (Issue.v ~loc { suite_name; issue_type = Not_snake_case suite_name })
  else if suite_name <> expected_name then
    Some
      (Issue.v ~loc
         {
           suite_name;
           issue_type =
             Wrong_name { actual = suite_name; expected = expected_name };
         })
  else None

let is_test_module_file filename =
  let basename = Filename.basename filename in
  String.starts_with ~prefix:"test_" basename && File_kind.is_ml basename

let issues_of_view ~filename view =
  let expected_name = extract_expected_name filename in
  match suite_name view with
  | None -> []
  | Some found -> (
      match suite_issue ~filename ~expected_name found with
      | None -> []
      | Some issue -> [ issue ])

let check (ctx : Context.file) =
  let filename = ctx.filename in
  if is_test_module_file filename then
    issues_of_view ~filename (Context.view ctx)
  else []

let pp ppf { suite_name; issue_type } =
  match issue_type with
  | Not_lowercase suggested ->
      Fmt.pf ppf "Test suite name '%s' should be lowercase - use '%s' instead"
        suite_name suggested
  | Not_snake_case _ ->
      Fmt.pf ppf "Test suite name '%s' should use snake_case naming convention"
        suite_name
  | Wrong_name { actual = _; expected } ->
      Fmt.pf ppf
        "Test suite name '%s' should match the filename - expected '%s'"
        suite_name expected

let rule =
  Rule.v ~code:"E617" ~title:"Test Suite Naming Convention" ~category:Testing
    ~hint:
      "Test suite names should follow these conventions: (1) Use lowercase \
       snake_case for the suite name. (2) The suite name should match the test \
       file name - for example, test_foo.ml should have suite name 'foo'. This \
       makes it easier to identify which test file contains which suite."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|(* In test_config.ml *)
let suite = ("Config", tests)  (* Wrong: uppercase *)

(* In test_user_auth.ml *)
let suite = ("auth", tests)  (* Wrong: doesn't match filename *)

(* In test_parser.ml *)
let suite = ("parser-tests", tests)  (* Wrong: not snake_case *)|};
        };
        {
          is_good = true;
          code =
            {|(* In test_config.ml *)
let suite = ("config", tests)

(* In test_user_auth.ml *)
let suite = ("user_auth", tests)

(* In test_parser.ml *)
let suite = ("parser", tests)|};
        };
      ]
    ~pp (File check)
