(** E621: Empty Test Suite *)

type payload = { suite_name : string }

(** [is_empty_list expr] returns true if [expr] is the empty list constructor
    [[]]. Handles module-opened lists like [M.[]], which appear as
    [Pexp_open (_, Pexp_construct ("[]", None))]. *)
let rec is_empty_list (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> true
  | Pexp_open (_, inner) -> is_empty_list inner
  | _ -> false

(** Find [let suite = ("name", [])] in a parsed structure, returning
    [(suite_name, loc)] if the test list is empty. *)
let find_empty_suite structure =
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
            ] ) -> (
          match pvb_expr.pexp_desc with
          | Pexp_tuple [ (_ (* label *), _ (* name *)); (_, list_expr) ] ->
              if is_empty_list list_expr then Some pvb_expr.pexp_loc else None
          | _ -> None)
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
    let content = Context.content ctx in
    let structure =
      try
        let lexbuf = Lexing.from_string content in
        lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
        Some (Parse.implementation lexbuf)
      with Syntaxerr.Error _ | Lexer.Error _ -> None
    in
    match structure with
    | None -> []
    | Some structure -> (
        match find_empty_suite structure with
        | None -> []
        | Some loc ->
            let suite_name =
              (* Re-extract the name for the message; fall back to filename. *)
              let fp = Fpath.v filename in
              Fpath.(fp |> rem_ext |> basename) |> fun s ->
              if String.starts_with ~prefix:"test_" s then
                String.sub s 5 (String.length s - 5)
              else s
            in
            let loc =
              Location.v ~file:filename ~start_line:loc.loc_start.pos_lnum
                ~start_col:0 ~end_line:loc.loc_start.pos_lnum ~end_col:80
            in
            [ Issue.v ~loc { suite_name } ])

let pp ppf { suite_name } =
  Fmt.pf ppf
    "Test suite '%s' is empty — add meaningful tests covering the public API, \
     edge cases, and error paths"
    suite_name

let rule =
  Rule.v ~code:"E621" ~title:"Empty Test Suite" ~category:Testing
    ~hint:
      "An empty test suite provides no value. Tests should: (1) cover the \
       module's public API with representative inputs, (2) exercise boundary \
       conditions and edge cases, (3) verify error handling and invalid \
       inputs, (4) document expected behaviour through concrete examples. A \
       suite with no test cases will never catch regressions."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let suite = ("parser", [])  (* no tests: regressions go undetected *)|};
        };
        {
          is_good = true;
          code =
            {|let suite =
  ( "parser",
    [
      Alcotest.test_case "parses valid input" `Quick test_parse_valid;
      Alcotest.test_case "rejects empty input" `Quick test_parse_empty;
      Alcotest.test_case "handles malformed data" `Quick test_parse_malformed;
    ] )|};
        };
      ]
    ~pp (File check)
