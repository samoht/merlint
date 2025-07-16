(** E001: High Cyclomatic Complexity - New self-contained rule *)

open Rule
open Issue

type config = { max_complexity : int }

let format_issue = function
  | Complexity_exceeded { name; complexity; threshold } ->
      Fmt.str "Function '%s' has cyclomatic complexity of %d (threshold: %d)" 
        name complexity threshold
  | _ -> failwith "E001: unexpected issue data"

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
            Issue.create 
              ~rule_id:Complexity
              ~location
              ~data:(Complexity_exceeded { 
                name; 
                complexity; 
                threshold = config.max_complexity 
              })
          ]
        else []
  | None -> []

let check_file (ctx : Context.file) =
  let config = { max_complexity = ctx.config.max_complexity } in
  let browse_data = Context.browse ctx in

  (* Use traverse helper to process only function bindings *)
  let function_bindings =
    Traverse.filter_functions browse_data.value_bindings
  in
  List.concat_map (analyze_value_binding config) function_bindings

let rule =
  v
    ~id:Complexity
    ~title:"High Cyclomatic Complexity"
    ~category:Rule.Complexity
    ~hint:"This issue means your functions have too much conditional logic (if \
           statements, pattern matches, loops) making them hard to understand and \
           test. Each decision point adds a possible path through the code. Fix it \
           by extracting complex conditions into helper functions or splitting the \
           function into smaller, focused functions."
    ~examples:[
      bad {|let process_order order =
  if order.status = "pending" then
    if order.payment_verified then
      if order.items <> [] then
        if check_inventory order.items then
          if validate_shipping order.address then
            ship_order order
          else
            error "Invalid address"
        else
          error "Out of stock"
      else
        error "No items"
    else
      error "Payment failed"
  else
    error "Invalid status"|};
      good {|let validate_order order =
  match order.status with
  | "pending" -> Ok order
  | status -> Error ("Invalid status: " ^ status)

let check_payment order =
  if order.payment_verified then Ok order
  else Error "Payment failed"

let process_order order =
  order
  |> validate_order
  |> Result.bind check_payment
  |> Result.bind validate_items
  |> Result.bind ship_if_ready|};
    ]
    ~check:(File_check check_file)
    ~format_issue
    ()