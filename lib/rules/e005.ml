(** E005: Function Too Long *)

type payload = { name : string; length : int; threshold : int }
(** Payload for function length issues *)

type config = { max_function_length : int }

(** Calculate adjusted threshold for pattern matching functions *)
let calculate_adjusted_threshold config has_pattern case_count =
  if has_pattern then
    (* For pattern matching heavy functions, allow 2-3 lines per case *)
    let base_threshold = config.max_function_length in
    let pattern_allowance = case_count * 2 in
    max base_threshold (base_threshold + pattern_allowance)
  else config.max_function_length

let check (ctx : Context.file) =
  let config =
    { max_function_length = ctx.Context.config.max_function_length }
  in
  let ast = Context.ast ctx in

  (* Analyze each function in the AST *)
  List.filter_map
    (fun (name, expr) ->
      (* Use visitor to extract function structure information *)
      let visitor = new Ast.function_structure_visitor () in
      visitor#visit_expr expr;
      let structure_info = visitor#get_info in

      (* Calculate function length by counting non-empty lines in expression *)
      let length = Ast.calculate_expr_line_count expr in

      (* Calculate adjusted threshold for pattern matching functions *)
      let adjusted_threshold =
        calculate_adjusted_threshold config structure_info.has_pattern_match
          structure_info.case_count
      in

      if length > adjusted_threshold then
        (* Create a dummy location for now - we'll improve this later *)
        let loc =
          Location.create ~file:ctx.filename ~start_line:1 ~start_col:0
            ~end_line:1 ~end_col:0
        in
        Some (Issue.v ~loc { name; length; threshold = adjusted_threshold })
      else None)
    ast.functions

let pp ppf { name; length; threshold } =
  Fmt.pf ppf "Function '%s' is %d lines long (threshold: %d)" name length
    threshold

let rule =
  Rule.v ~code:"E005" ~title:"Long Functions" ~category:Complexity
    ~hint:
      "This issue means your functions are too long and hard to read. Fix them \
       by extracting logical sections into separate functions with descriptive \
       names. Note: Functions with pattern matching get additional allowance \
       (2 lines per case). Pure data structures (lists, records) are also \
       exempt from length checks. For better readability, consider using \
       helper functions for complex logic. Aim for functions under 50 lines of \
       actual logic."
    ~examples:[] ~pp (File check)
