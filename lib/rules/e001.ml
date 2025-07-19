(** E001: High Cyclomatic Complexity *)

type payload = { name : string; complexity : int; threshold : int }
(** Payload for complexity issues *)

type config = { max_complexity : int }

let src = Logs.Src.create "merlint.e001" ~doc:"E001 rule"

module Log = (val Logs.src_log src : Logs.LOG)

let check (ctx : Context.file) =
  let config = { max_complexity = ctx.Context.config.max_complexity } in
  let functions = Context.functions ctx in

  Log.debug (fun m -> m "E001: Found %d functions" (List.length functions));

  (* Analyze each function *)
  List.filter_map
    (fun (name, expr) ->
      let complexity_info = Ast.Complexity.analyze expr in
      let complexity = Ast.Complexity.calculate complexity_info in

      Log.debug (fun m ->
          m "Function %s: expr=%s" name
            (match expr with
            | Ast.Function _ -> "Function"
            | Ast.If_then_else _ -> "If_then_else"
            | Ast.Match _ -> "Match"
            | Ast.Try _ -> "Try"
            | Ast.Let _ -> "Let"
            | _ -> "Other"));
      Log.debug (fun m ->
          m
            "Function %s: complexity_info={if_then_else=%d; match_cases=%d; \
             try_handlers=%d; boolean_operators=%d; total=%d}"
            name complexity_info.if_then_else complexity_info.match_cases
            complexity_info.try_handlers complexity_info.boolean_operators
            complexity_info.total);
      Log.debug (fun m ->
          m "Function %s: complexity=%d (threshold=%d)" name complexity
            config.max_complexity);

      if complexity > config.max_complexity then
        (* Create a dummy location for now - we'll improve this later *)
        let loc =
          Location.create ~file:ctx.filename ~start_line:1 ~start_col:0
            ~end_line:1 ~end_col:0
        in
        Some
          (Issue.v ~loc { name; complexity; threshold = config.max_complexity })
      else None)
    functions

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
