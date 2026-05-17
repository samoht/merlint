(** E340: Error Pattern Detection *)

module T = Ocaml_typing.Typedtree

type payload = { error_message : string; suggested_function : string }
(** Payload for error pattern issues *)

let issue ~loc error_message =
  Issue.v ~loc { error_message; suggested_function = "err_*" }

let is_fmt_str_call expr = Query.Expr.calls expr [ "Fmt"; "str" ]

let error_payload_message (arg : T.expression) =
  if is_fmt_str_call arg then Some "Error applied to Fmt.str"
  else
    match arg.exp_desc with
    | Texp_variant ("Msg", Some msg) when is_fmt_str_call msg ->
        Some "Error (`Msg ...) applied to Fmt.str"
    | _ -> None

let error_constructor lid = Query.Longident.ends_with lid [ "Error" ]

let helper_range (vb : T.value_binding) =
  match Query.Pattern.var_name vb.vb_pat with
  | Some name when String.starts_with ~prefix:"err_" name -> Some vb.vb_loc
  | _ -> None

let error_helper_ranges view =
  let ranges = ref [] in
  Query.iter_value_bindings view (fun vb ->
      Option.iter (fun loc -> ranges := loc :: !ranges) (helper_range vb));
  !ranges

let loc_contains_line (loc : Ocaml_parsing.Location.t) line_num =
  line_num >= loc.loc_start.pos_lnum && line_num <= loc.loc_end.pos_lnum

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let view = Context.view ctx in
  let error_helpers = error_helper_ranges view in
  let is_inside_error_helper line_num =
    List.exists (fun loc -> loc_contains_line loc line_num) error_helpers
  in
  let issues = ref [] in
  Query.iter_expressions view (fun (expr : T.expression) ->
      match expr.exp_desc with
      | Texp_construct (lid, _, [ arg ]) ->
          let line_num = expr.exp_loc.loc_start.pos_lnum in
          if error_constructor lid.txt && not (is_inside_error_helper line_num)
          then
            Option.iter
              (fun error_message ->
                issues :=
                  issue ~loc:(Loc.of_typed ~filename expr.exp_loc) error_message
                  :: !issues)
              (error_payload_message arg)
      | _ -> ());
  List.rev !issues

let pp ppf { error_message; suggested_function } =
  Fmt.pf ppf
    "Found '%s' pattern - consider using '%s' helper functions for consistent \
     error handling"
    error_message suggested_function

let rule =
  Rule.v ~code:"E340" ~title:"Error Pattern Detection"
    ~category:Style_modernization
    ~hint:
      "Using raw Error constructors with Fmt.str (including polymorphic \
       variants like `Msg) can lead to inconsistent error messages. Consider \
       creating error helper functions (prefixed with 'err_') that encapsulate \
       common error patterns and provide consistent formatting. Place these \
       error helpers at the top of the file to make it easier to see all the \
       different error cases in one place."
    ~examples:
      [ Example.bad Examples.E340.bad_ml; Example.good Examples.E340.good_ml ]
    ~pp (File check)
