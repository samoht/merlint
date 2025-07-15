(** E010: Deep Nesting *)

type config = { max_nesting : int }

(** Analyze a single value binding for nesting depth *)
let analyze_value_binding config binding =
  match binding.Browse.ast_elt.location with
  | Some location ->
      let name = Ast.name_to_string binding.ast_elt.name in

      (* Only check functions, not simple values *)
      if not binding.is_function then []
      else
        (* TODO: E010 - Implement nesting depth calculation
           This requires analyzing the AST to track nesting levels of:
           - if-then-else statements
           - match expressions
           - let-in expressions
           - while/for loops
           - try-with blocks
           
           Currently, Browse data doesn't provide enough information
           to calculate nesting depth. This means E010 will never
           detect deep nesting issues! *)
        let nesting = 0 in
        (* Always 0 - not implemented *)

        if nesting > config.max_nesting then
          [
            Issue.Deep_nesting
              {
                name;
                location;
                depth = nesting;
                threshold = config.max_nesting;
              };
          ]
        else []
  | None -> []

let check config browse_data =
  let bindings = Browse.get_value_bindings browse_data in
  List.concat_map (analyze_value_binding config) bindings
