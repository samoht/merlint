(** E005: Function Too Long *)

type payload = { name : string; length : int; threshold : int }
(** Payload for function length issues *)

let log_src = Logs.Src.create "merlint.rules.e005" ~doc:"E005 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

type config = { max_function_length : int }

let is_test_file filename =
  let module_name =
    Filename.basename filename |> Filename.remove_extension
    |> String.lowercase_ascii
  in
  String.starts_with ~prefix:"test_" module_name
  || String.contains filename '/'
     && String.contains (Filename.dirname filename) '/'
     && List.exists
          (fun part -> part = "test")
          (String.split_on_char '/' filename)

let rec is_pure_data_structure = function
  | Ast.List -> true
  | Ast.Record { fields } when fields >= 3 -> true
  | Ast.Sequence exprs -> List.for_all is_pure_data_structure exprs
  | Ast.Other -> false
  | Ast.Let _ | Ast.Function _ | Ast.If_then_else _ | Ast.Match _ | Ast.Try _ ->
      false
  | Ast.Record { fields = _ } -> false

let rec count_match_cases = function
  | Ast.Match { cases; _ } -> List.length cases
  | Ast.Function { body; _ } -> count_match_cases body
  | Ast.Let { body; bindings } ->
      let binding_cases =
        List.fold_left
          (fun acc (_, expr) -> acc + count_match_cases expr)
          0 bindings
      in
      binding_cases + count_match_cases body
  | Ast.If_then_else { then_expr; else_expr; _ } ->
      let else_cases = Option.fold ~none:0 ~some:count_match_cases else_expr in
      count_match_cases then_expr + else_cases
  | Ast.Sequence exprs ->
      List.fold_left (fun acc expr -> acc + count_match_cases expr) 0 exprs
  | Ast.Try { expr; _ } -> count_match_cases expr
  | Ast.List | Ast.Record _ | Ast.Other -> 0

let function_expr ast name =
  List.find_opt (fun (n, _) -> n = name) ast.Ast.functions

let function_threshold config func_expr =
  let match_cases =
    match func_expr with Some (_, expr) -> count_match_cases expr | None -> 0
  in
  let trailing_record =
    match func_expr with
    | Some (_, expr) -> Ast.trailing_record_fields expr
    | None -> 0
  in
  config.max_function_length + (match_cases * 2) + trailing_record

let is_data_def ast name =
  List.exists
    (fun (n, expr) -> n = name && is_pure_data_structure expr)
    ast.Ast.functions

let issue_of_item ~filename ~config ~ast (item : Outline.item) =
  match item.kind with
  | Value ->
      let loc = item.location in
      let length = loc.end_.line - loc.start.line + 1 in
      if is_data_def ast item.name then (
        Log.debug (fun m -> m "Skipping pure data structure: %s" item.name);
        None)
      else
        let func_expr = function_expr ast item.name in
        let threshold = function_threshold config func_expr in
        if length <= threshold then None
        else
          let issue_loc =
            Location.v ~file:filename ~start_line:loc.start.line
              ~start_col:loc.start.col ~end_line:loc.end_.line
              ~end_col:loc.end_.col
          in
          Some
            (Issue.v ~loc:issue_loc ~severity:(length - threshold)
               { name = item.name; length; threshold })
  | Type | Module | Module_type | Class | Class_type | Exception | Constructor
  | Field | Method | Label ->
      None

let check (ctx : Context.file) =
  let config =
    { max_function_length = ctx.Context.config.max_function_length }
  in
  let filename = ctx.filename in
  Log.debug (fun m ->
      m "E005: Checking %s (is_test=%b)" filename (is_test_file filename));
  if is_test_file filename then []
  else
    List.filter_map
      (issue_of_item ~filename ~config ~ast:(Context.ast ctx))
      (Context.outline ctx)

let pp ppf { name; length; threshold } =
  Fmt.pf ppf "Function '%s' is %d lines long (threshold: %d)" name length
    threshold

let rule =
  Rule.v ~code:"E005" ~title:"Long Functions" ~category:Complexity
    ~hint:
      "This issue means your functions are too long and hard to read. Fix them \
       by extracting logical sections into separate functions with descriptive \
       names. Note: Functions with pattern matching get additional allowance \
       (2 lines per case). Pure data structures (lists, records) are exempt \
       from length checks. For better readability, consider using helper \
       functions for complex logic. Aim for functions under 50 lines of actual \
       logic."
    ~examples:
      [ Example.bad Examples.E005.bad_ml; Example.good Examples.E005.good_ml ]
    ~pp (File check)
