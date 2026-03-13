(** E726: Empty Fuzz Suite *)

type payload = { suite_name : string }

(** [is_empty_list expr] returns true if [expr] is the empty list constructor
    [[]]. Handles module-opened lists like [Crowbar.[]], which appear as
    [Pexp_open (_, Pexp_construct ("[]", None))]. *)
let rec is_empty_list (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> true
  | Pexp_open (_, inner) -> is_empty_list inner
  | _ -> false

(** Find [let suite = ("name", [])] in a parsed structure, returning [loc] if
    the test list is empty. *)
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
      (String.starts_with ~prefix:"fuzz_" basename
      && String.ends_with ~suffix:".ml" basename)
  then []
  else
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
        match find_empty_suite structure with
        | None -> []
        | Some loc ->
            let suite_name =
              let fp = Fpath.v filename in
              Fpath.(fp |> rem_ext |> basename) |> fun s ->
              if String.starts_with ~prefix:"fuzz_" s then
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
    "Fuzz suite '%s' is empty — add meaningful fuzz tests covering parsers, \
     encoders, state machines, and edge cases"
    suite_name

let rule =
  Rule.v ~code:"E726" ~title:"Empty Fuzz Suite" ~category:Testing
    ~hint:
      "An empty fuzz suite provides no coverage. Fuzz tests should: (1) test \
       crash safety of all parsers and decoders on arbitrary input, (2) verify \
       roundtrip invariants (decode(encode(x)) = x), (3) exercise state \
       machine transitions including invalid ones, (4) cover boundary \
       conditions and edge cases that unit tests miss. A suite with no test \
       cases will never find bugs."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let suite = ("parser", Crowbar.[])  (* no fuzz tests: bugs go undetected *)|};
        };
        {
          is_good = true;
          code =
            {|let suite =
  ( "parser",
    Crowbar.
      [
        test_case "parse crash safety" [ bytes ] test_parse;
        test_case "roundtrip" [ bytes ] test_roundtrip;
        test_case "boundary: empty input" [ const () ] test_empty;
      ] )|};
        };
      ]
    ~pp (File check)
