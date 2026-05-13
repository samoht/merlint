(** E617: Test Suite Naming Convention *)

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

(** Extract suite name from a [let suite = ...] binding using the AST. Handles
    both [let suite = ("name", ...)] and [let suite = \n  ("name", ...)]. *)
let extract_suite_name_of_expr (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_tuple
      (( _,
         {
           pexp_desc =
             Pexp_constant { pconst_desc = Pconst_string (name, _, _); _ };
           _;
         } )
      :: _) ->
      Some (name, expr.pexp_loc)
  | _ -> None

(** Find the suite name from a parsed structure by looking for
    [let suite = ("name", ...)] bindings. *)
let find_suite_name structure =
  List.find_map
    (fun (item : Parsetree.structure_item) ->
      match item.pstr_desc with
      | Pstr_value
          ( _,
            [
              {
                pvb_pat = { ppat_desc = Ppat_var { txt = "suite"; _ }; _ };
                pvb_expr;
                _;
              };
            ] ) ->
          extract_suite_name_of_expr pvb_expr
      | _ -> None)
    structure

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let basename = Filename.basename filename in
  if
    not
      (String.starts_with ~prefix:"test_" basename
      && String.ends_with ~suffix:".ml" basename)
  then []
  else
    let expected_name = extract_expected_name filename in
    let content = Context.content ctx in
    let structure =
      try
        let lexbuf = Lexing.from_string content in
        lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
        Some (Parse.implementation lexbuf)
      with _ -> None
    in
    match structure with
    | None -> []
    | Some structure -> (
        match find_suite_name structure with
        | None -> []
        | Some (suite_name, name_loc) ->
            let loc =
              Location.v ~file:filename ~start_line:name_loc.loc_start.pos_lnum
                ~start_col:0 ~end_line:name_loc.loc_start.pos_lnum ~end_col:80
            in
            if suite_name <> String.lowercase_ascii suite_name then
              [
                Issue.v ~loc
                  {
                    suite_name;
                    issue_type =
                      Not_lowercase (String.lowercase_ascii suite_name);
                  };
              ]
            else if not (is_snake_case suite_name) then
              [
                Issue.v ~loc
                  { suite_name; issue_type = Not_snake_case suite_name };
              ]
            else if suite_name <> expected_name then
              [
                Issue.v ~loc
                  {
                    suite_name;
                    issue_type =
                      Wrong_name
                        { actual = suite_name; expected = expected_name };
                  };
              ]
            else [])

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
