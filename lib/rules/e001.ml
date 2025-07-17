(** E001: High Cyclomatic Complexity *)

type payload = { name : string; complexity : int; threshold : int }
(** Payload for complexity issues *)

type config = { max_complexity : int }

let check (ctx : Context.file) =
  let config = { max_complexity = ctx.Context.config.max_complexity } in
  let ast = Context.ast ctx in

  (* Analyze each function in the AST *)
  List.filter_map
    (fun (name, expr) ->
      let complexity_info = Ast.Complexity.analyze_expr expr in
      let complexity = Ast.Complexity.calculate complexity_info in

      if complexity > config.max_complexity then
        (* Create a dummy location for now - we'll improve this later *)
        let loc =
          Location.create ~file:ctx.filename ~start_line:1 ~start_col:0
            ~end_line:1 ~end_col:0
        in
        Some
          (Issue.v ~loc { name; complexity; threshold = config.max_complexity })
      else None)
    ast.functions

let pp ppf { name; complexity; threshold } =
  Fmt.pf ppf "Function '%s' has cyclomatic complexity of %d (threshold: %d)"
    name complexity threshold

let rule =
  Rule.v ~code:"E001" ~title:"High Cyclomatic Complexity" ~category:Complexity
    ~hint:
      "High cyclomatic complexity makes code harder to understand and test. \
       Consider breaking complex functions into smaller, more focused \
       functions. Each function should ideally do one thing well."
    ~examples:[] ~pp (File check)
