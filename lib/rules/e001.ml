(** E001: High Cyclomatic Complexity *)

type config = { max_complexity : int }

(** Analyze a single value binding for complexity *)
let analyze_value_binding config binding =
  match binding.Browse.ast_elt.location with
  | Some location ->
      let name = Ast.name_to_string binding.ast_elt.name in

      (* Only check functions, not simple values *)
      if not binding.is_function then []
      else
        (* TODO: E001 - Implement proper cyclomatic complexity calculation
           This requires analyzing the AST to count:
           - if-then-else statements (+1 for each)
           - match expressions (+1 for each case beyond the first)
           - while/for loops (+1 for each)
           - try-with blocks (+1 for each)
           - && and || operators (+1 for each)
           
           For now, we use pattern match count as a rough approximation.
           This means E001 will not properly detect high complexity! *)
        let complexity =
          if binding.pattern_info.has_pattern_match then
            1 + binding.pattern_info.case_count
          else 1 (* Base complexity *)
        in

        if complexity > config.max_complexity then
          [
            Issue.Complexity_exceeded
              { name; location; complexity; threshold = config.max_complexity };
          ]
        else []
  | None -> []

let check config browse_data =
  let bindings = Browse.get_value_bindings browse_data in
  List.concat_map (analyze_value_binding config) bindings
