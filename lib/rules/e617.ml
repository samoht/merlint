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

let check (ctx : Context.file) =
  (* Only check test files (those starting with test_) *)
  let filename = ctx.filename in
  let basename = Filename.basename filename in
  if
    not
      (String.starts_with ~prefix:"test_" basename
      && String.ends_with ~suffix:".ml" basename)
  then []
  else
    let expected_name = extract_expected_name filename in

    (* Simple approach: look for suite definition line directly in content *)
    let content = Context.content ctx in
    let lines = String.split_on_char '\n' content in

    (* Find line containing "let suite =" *)
    let suite_line =
      List.find_opt
        (fun line ->
          let line_trimmed = String.trim line in
          String.starts_with ~prefix:"let suite " line_trimmed)
        lines
    in

    match suite_line with
    | Some line -> (
        (* Extract suite name from quotes *)
        let quote_start = String.index_opt line '"' in
        match quote_start with
        | Some start -> (
            let quote_end = String.index_from_opt line (start + 1) '"' in
            match quote_end with
            | Some end_pos ->
                let suite_name =
                  String.sub line (start + 1) (end_pos - start - 1)
                in

                (* Find line number for location *)
                let line_num = ref 0 in
                List.iteri (fun i l -> if l = line then line_num := i + 1) lines;
                let loc =
                  Location.v ~file:filename ~start_line:!line_num ~start_col:0
                    ~end_line:!line_num ~end_col:(String.length line)
                in

                (* Check if suite name is lowercase *)
                if suite_name <> String.lowercase_ascii suite_name then
                  [
                    Issue.v ~loc
                      {
                        suite_name;
                        issue_type =
                          Not_lowercase (String.lowercase_ascii suite_name);
                      };
                  ] (* Check if suite name is snake_case *)
                else if not (is_snake_case suite_name) then
                  [
                    Issue.v ~loc
                      { suite_name; issue_type = Not_snake_case suite_name };
                  ] (* Check if suite name matches expected *)
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
                else []
            | None -> [])
        | None -> [])
    | None -> []

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
