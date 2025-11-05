(** E005: Function Too Long *)

type payload = { name : string; length : int; threshold : int }
(** Payload for function length issues *)

type config = { max_function_length : int }

let check (ctx : Context.file) =
  let config =
    { max_function_length = ctx.Context.config.max_function_length }
  in
  let outline = Context.outline ctx in
  let ast = Context.ast ctx in

  (* Skip length checks for test modules - it's ok to have long test functions *)
  let module_name =
    Filename.basename ctx.filename
    |> Filename.remove_extension |> String.lowercase_ascii
  in
  let is_test_file =
    String.starts_with ~prefix:"test_" module_name
    ||
    (* Also check if file is in a test directory *)
    String.contains ctx.filename '/'
    && String.contains (Filename.dirname ctx.filename) '/'
    && List.exists
         (fun part -> part = "test")
         (String.split_on_char '/' ctx.filename)
  in

  Logs.debug (fun m ->
      m "E005: Checking %s (module_name=%s, is_test=%b)" ctx.filename
        module_name is_test_file);

  if is_test_file then []
  else
    (* Helper to check if an expression is a pure data structure *)
    let rec is_pure_data_structure = function
      | Ast.List -> true (* List and array literals *)
      | Ast.Record { fields } when fields >= 3 ->
          true (* Large record literals *)
      | Ast.Sequence exprs -> List.for_all is_pure_data_structure exprs
      | Ast.Other -> false (* Conservative: don't assume Other is pure data *)
      | Ast.Let _ | Ast.Function _ | Ast.If_then_else _ | Ast.Match _
      | Ast.Try _ ->
          false (* Functions definitely have logic *)
      | Ast.Record { fields = _ } -> false (* Small records might have logic *)
    in

    (* Count total match cases in an expression *)
    let rec count_match_cases = function
      | Ast.Match { cases; _ } -> cases
      | Ast.Function { body; _ } -> count_match_cases body
      | Ast.Let { body; bindings } ->
          let binding_cases =
            List.fold_left
              (fun acc (_, expr) -> acc + count_match_cases expr)
              0 bindings
          in
          binding_cases + count_match_cases body
      | Ast.If_then_else { then_expr; else_expr; _ } ->
          let then_cases = count_match_cases then_expr in
          let else_cases =
            match else_expr with
            | Some expr -> count_match_cases expr
            | None -> 0
          in
          then_cases + else_cases
      | Ast.Sequence exprs ->
          List.fold_left (fun acc expr -> acc + count_match_cases expr) 0 exprs
      | Ast.Try { expr; _ } -> count_match_cases expr
      | Ast.List | Ast.Record _ | Ast.Other -> 0
    in

    (* Analyze each function from the outline *)
    List.filter_map
      (fun (item : Outline.item) ->
        match item.kind with
        | Value -> (
            (* Calculate function length from outline location *)
            match item.range with
            | Some range ->
                let length = range.end_.line - range.start.line + 1 in

                (* Check if this is a pure data structure *)
                let is_data_def =
                  List.exists
                    (fun (name, expr) ->
                      name = item.name && is_pure_data_structure expr)
                    ast.functions
                in

                (* Skip length check for pure data structures *)
                if is_data_def then (
                  Logs.debug (fun m ->
                      m "Skipping pure data structure: %s" item.name);
                  None)
                else
                  (* Find the function's AST to count match cases *)
                  let match_cases =
                    match
                      List.find_opt
                        (fun (name, _) -> name = item.name)
                        ast.functions
                    with
                    | Some (_, expr) -> count_match_cases expr
                    | None -> 0
                  in

                  (* Apply additional allowance for pattern matching (2 lines per case) *)
                  let threshold =
                    config.max_function_length + (match_cases * 2)
                  in

                  if length > threshold then
                    let loc =
                      Location.v ~file:ctx.filename ~start_line:range.start.line
                        ~start_col:range.start.col ~end_line:range.end_.line
                        ~end_col:range.end_.col
                    in
                    Some (Issue.v ~loc { name = item.name; length; threshold })
                  else None
            | None -> None)
        | Type | Module | Class | Exception | Constructor | Field | Method
        | Other _ ->
            None)
      outline

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
