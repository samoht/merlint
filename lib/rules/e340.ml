(** E340: Error Pattern Detection *)

open Ocaml_parsing

type payload = { error_message : string; suggested_function : string }
(** Payload for error pattern issues *)

let issue ~loc error_message =
  Issue.v ~loc { error_message; suggested_function = "err_*" }

let rec is_fmt_str_call (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _) ->
      Longident.flatten txt = [ "Fmt"; "str" ]
  | Pexp_constraint (expr, _) | Pexp_coerce (expr, _, _) -> is_fmt_str_call expr
  | Pexp_open (_, expr) -> is_fmt_str_call expr
  | _ -> false

let error_payload_message (arg : Parsetree.expression) =
  if is_fmt_str_call arg then Some "Error applied to Fmt.str"
  else
    match arg.pexp_desc with
    | Pexp_variant ("Msg", Some msg) when is_fmt_str_call msg ->
        Some "Error (`Msg ...) applied to Fmt.str"
    | _ -> None

let error_constructor lid =
  match List.rev (Longident.flatten lid) with
  | "Error" :: _ -> true
  | _ -> false

let check (ctx : Context.file) =
  let filename = ctx.filename in
  let outline = Context.outline ctx in

  let error_helpers =
    Outline.values outline
    |> List.filter_map (fun (item : Outline.item) ->
        if String.starts_with ~prefix:"err_" item.name then
          Some (item.name, item.location)
        else None)
  in

  (* Check if a line number is inside any error helper function *)
  let is_inside_error_helper line_num =
    List.exists
      (fun (_name, (loc : Merlin.location)) ->
        line_num >= loc.start.line && line_num <= loc.end_.line)
      error_helpers
  in

  match File_view.parsetree (Context.view ctx) with
  | None -> []
  | Some structure ->
      let issues = ref [] in
      Ast.iter_expressions structure (fun (expr : Parsetree.expression) ->
          match expr.pexp_desc with
          | Pexp_construct ({ txt; _ }, Some arg) -> (
              let line_num = expr.pexp_loc.loc_start.pos_lnum in
              if error_constructor txt && not (is_inside_error_helper line_num)
              then
                match error_payload_message arg with
                | Some error_message ->
                    issues :=
                      issue
                        ~loc:(Ast.merlint_of_loc ~filename expr.pexp_loc)
                        error_message
                      :: !issues
                | None -> ())
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
