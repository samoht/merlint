(** E001: High Cyclomatic Complexity *)

type payload = { name : string; complexity : int; threshold : int }
(** Payload for complexity issues *)

type config = { max_complexity : int }

(** Analyze a single value binding for complexity *)
let analyze_value_binding config binding =
  match binding.Browse.ast_elt.location with
  | Some loc ->
      let name = Ast.name_to_string binding.ast_elt.name in

      (* Only check functions, not simple values *)
      if not binding.is_function then []
      else
        (* For now, use pattern match count as a rough approximation of complexity
           TODO: Implement proper cyclomatic complexity calculation by parsing
           the AST to count:
           - if-then-else statements (+1 for each)
           - match expressions (+1 for each case beyond the first)
           - while/for loops (+1 for each)
           - try-with blocks (+1 for each)
           - && and || operators (+1 for each) *)
        let complexity =
          if binding.pattern_info.has_pattern_match then
            1 + binding.pattern_info.case_count
          else 1 (* Base complexity *)
        in

        if complexity > config.max_complexity then
          [
            Issue.v ~loc { name; complexity; threshold = config.max_complexity };
          ]
        else []
  | None -> []

let check (ctx : Context.file) =
  let config = { max_complexity = ctx.Context.config.max_complexity } in
  let browse_data = Context.browse ctx in

  (* Use traverse helper to process only function bindings *)
  let function_bindings =
    Traverse.filter_functions browse_data.value_bindings
  in
  List.concat_map (analyze_value_binding config) function_bindings

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
